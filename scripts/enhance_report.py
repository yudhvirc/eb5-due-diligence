#!/usr/bin/env python3
"""Post-render enhancement pass for EB-5 reports (the "house format").

`render_report.ps1` emits the deterministic skeleton; this script layers on the
presentation the reports are expected to carry. Everything here is data-driven from
`findings.json` and the two bundled assets (`report-factors.json`,
`report-glossary.json`) and reuses the template's own design system (`--accent`,
`--go`/`--cond`/`--nogo`, `.panel`, `.chip`, `.grid.g2`, `.sub`, `.jt`/`.ji`/`.ji-pop`)
so injected sections look native.

Every pass is idempotent -- each writes an HTML comment marker and is skipped if the
marker is already present -- so it is safe to re-run over an already-enhanced file.

Usage
    python enhance_report.py --html report.html --findings findings.json
    python enhance_report.py --html eb5-compare.html --findings a.json,b.json,c.json
    python enhance_report.py --html r.html --findings f.json --only timeline,jargon
    python enhance_report.py --html r.html --findings f.json --skip jargon --out out.html

Order matters: `jargon` always runs last so terms introduced by the other passes get
icons too. See skills/eb5-report/SKILL.md for the specification each pass implements.
"""

import argparse
import html
import json
import pathlib
import re
import sys

HERE = pathlib.Path(__file__).resolve().parent
ASSETS = HERE.parent / "assets"

FACTOR_IDS = ["I1", "I2", "I3", "I4", "I5", "I6", "I7", "I8", "I9",
              "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10"]

VERDICT_VAR = {"GO": "var(--go)", "CONDITIONAL": "var(--cond)", "NO-GO": "var(--nogo)"}
DISPO_STYLE = {
    "ACCEPT":   ("var(--go)",     "#fff",    "Note it - should not delay your decision"),
    "CAUTION":  ("var(--cond)",   "#1a1a1a", "Proceed, but finish one named check before wiring"),
    "MITIGATE": ("var(--high)",   "#1a1a1a", "Proceed only on getting something specific in writing"),
    "AVOID":    ("var(--nogo)",   "#fff",    "No investor-level fix exists"),
}
PROB_TEXT = {"P0": "remote (<5%)", "P1": "unlikely (5-20%)", "P2": "realistic (20-50%)",
             "P3": "likely (50-80%)", "P4": "near-certain (>80%)"}
SEV_TEXT = {"S1": "minor", "S2": "moderate", "S3": "severe", "S4": "green-card fatal / total loss"}
LINK = 'color:#4ea1ff;text-decoration:underline'

# Colour semantics (see skills/eb5-report/SKILL.md -> "Colour coding"):
# colour encodes ABSOLUTE quality; being the best of a set never earns a quality colour.
VERDICT_RE = re.compile(r"\b(NO-GO|CONDITIONAL|GO)\b")
SCORE_RE = re.compile(r"\b(\d{1,3})\s*/\s*100\b")
RANK_MARK = ";box-shadow:inset 3px 0 0 var(--accent)"


def band_var(n):
    """Risk-score band colour. 0 is best, 100 is worst; thresholds 35 / 60 per the rubric."""
    return "var(--go)" if n <= 35 else ("var(--cond)" if n <= 60 else "var(--nogo)")


def cell_style(text, good):
    """Style a one-pager cell.

    A verdict or an N/100 risk score is coloured by its OWN value and never by `good` --
    otherwise a NO-GO that is merely the least-bad column renders green and reads as a pass.
    `good` on such a cell adds a neutral accent rank marker instead. Elsewhere `good` means
    the value is genuinely favourable in absolute terms, and earns green.
    """
    t = text or ""
    m = VERDICT_RE.search(t)
    if m:
        return "color:%s;font-weight:700" % VERDICT_VAR[m.group(1)] + (RANK_MARK if good else "")
    m = SCORE_RE.search(t)
    if m:
        return "color:%s;font-weight:700" % band_var(int(m.group(1))) + (RANK_MARK if good else "")
    return "color:var(--go);font-weight:700" if good else ""

PASSES = ["heatmap", "srcdocs", "location", "keysources", "timeline",
          "disposition", "onepager", "questions", "jargon"]


# --------------------------------------------------------------------------- helpers

def esc(s):
    return html.escape(str(s if s is not None else ""), quote=True)


def load_asset(name):
    return json.loads((ASSETS / name).read_text(encoding="utf-8"))


def marker(pass_name, slug=""):
    return "<!--eb5:%s:%s-->" % (pass_name, re.sub(r"[^a-z0-9]+", "-", slug.lower()))


def project_name(f):
    return (f.get("project") or {}).get("name") or "project"


def location_str(f):
    loc = (f.get("project") or {}).get("location")
    if isinstance(loc, dict):
        parts = [loc.get(k) for k in ("address", "street", "city", "county", "state") if loc.get(k)]
        return ", ".join(str(p) for p in parts)
    return str(loc) if loc else ""


def verdict_of(f):
    return ((f.get("verdict") or {}).get("decision") or "").upper()


def key_sources(f, limit=6):
    """Tier->=2 non-issuer sources, best tier first, stable within tier."""
    out = []
    for i, s in enumerate(f.get("sources") or [], start=1):
        if s.get("is_issuer"):
            continue
        try:
            tier = int(s.get("tier", 0))
        except (TypeError, ValueError):
            tier = 0
        if tier >= 2 and s.get("url"):
            out.append((tier, i, s))
    out.sort(key=lambda t: (-t[0], t[1]))
    return out[:limit]


def source_links_html(f, limit=6, sep=" &middot; "):
    bits = []
    for tier, idx, s in key_sources(f, limit):
        bits.append('<a href="%s" target="_blank" rel="noopener" style="%s">%s &#8599;</a>'
                    % (esc(s["url"]), LINK, esc(s.get("title") or "source %d" % idx)))
    return sep.join(bits)


def panel(inner, border=None, style=""):
    b = ("border-left:4px solid %s;" % border) if border else ""
    return '<div class="panel" style="%s%s">%s</div>' % (b, style, inner)


def find_body_spans(h, findings):
    """Locate each project's accordion body in a comparison report.

    Returns {index_in_findings: insert_offset}. Falls back to the single-report
    insertion point (just after the verdict banner panel) when there are no accordions.
    """
    spans = {}
    for m in re.finditer(r'<details class="acc"><summary>(.*?)</summary><div class="body">', h, re.S):
        summary = re.sub(r"<[^>]+>", "", m.group(1))
        for i, f in enumerate(findings):
            if i in spans:
                continue
            name = project_name(f)
            if name and name.split(",")[0].strip().lower()[:28] in summary.lower():
                spans[i] = m.end()
                break
    return spans


def insertion_points(h, findings):
    """Yield (findings_index, offset) for per-project injections, outermost-last order.

    Injecting from the end backwards keeps earlier offsets valid.
    """
    spans = find_body_spans(h, findings)
    if spans:
        return sorted(spans.items(), key=lambda kv: -kv[1])
    m = re.search(r'<h2>Executive summary</h2>', h)
    if m and findings:
        return [(0, m.start())]
    return []


# ----------------------------------------------------------------------------- passes

def pass_heatmap(h, findings, _):
    """Heatmap header tooltips + a 'What the columns mean' legend with amber why-lines."""
    fac = load_asset("report-factors.json")["factors"]

    def add_title(m):
        fid = m.group(1)
        if fid not in fac:
            return m.group(0)
        return '<th class="num" title="%s">%s</th>' % (esc(fac[fid]["name"]), fid)

    h = re.sub(r'<th class="num">(' + "|".join(FACTOR_IDS) + r')</th>', add_title, h)

    if marker("heatmap") in h:
        return h
    rows = []
    for fid in FACTOR_IDS:
        if fid not in fac:
            continue
        rows.append(
            '<div style="margin:7px 0"><strong>%s</strong> &mdash; %s'
            '<div class="sub" style="color:#d6a700;margin-top:2px">Why it matters: %s</div></div>'
            % (fid, esc(fac[fid]["name"]), esc(fac[fid]["why"])))
    legend = marker("heatmap") + panel(
        "<h3>What the columns mean</h3>"
        '<p class="sub">I = immigration risk (your green card) &middot; F = financial risk (your $800,000). '
        "Every cell is 0-100 where <strong>lower is better</strong>. Tap the info icon next to any term for a "
        "plain-language definition.</p>"
        '<div class="grid g2">%s</div>' % "".join(rows), border="var(--accent)")

    anchor = re.search(r'<h2>Full reports</h2>', h)
    if anchor:
        return h[:anchor.start()] + legend + h[anchor.start():]
    return h.replace("<footer>", legend + "<footer>", 1)


def pass_srcdocs(h, findings, _):
    """'Source documents (locally provided)' panel at the top of each project section."""
    for i, off in insertion_points(h, findings):
        f = findings[i]
        mk = marker("srcdocs", project_name(f))
        if mk in h:
            continue
        docs = (f.get("project") or {}).get("source_documents") or []
        if docs:
            items = "".join("<li><code>%s</code></li>" % esc(d) for d in docs)
            inner = ("<h3>Source documents (locally provided)</h3>"
                     '<p class="sub">Read directly for this review. They are primary inputs, but an issuer '
                     "document never verifies itself &mdash; every material claim below was re-checked against "
                     "an independent source.</p>"
                     '<ul style="list-style:square;margin:6px 0 0 18px">%s</ul>' % items)
        else:
            inner = ("<h3>Source documents (locally provided)</h3>"
                     '<p class="sub"><strong>None received.</strong> This review rests entirely on public '
                     "sources. Offering documents would materially raise confidence.</p>")
        h = h[:off] + mk + panel(inner, border="var(--accent)") + h[off:]
    return h


def pass_location(h, findings, _):
    """A location bar at the top of each project section (drives RC-state and TEA checks)."""
    for i, off in insertion_points(h, findings):
        f = findings[i]
        mk = marker("location", project_name(f))
        loc = location_str(f)
        if mk in h or not loc:
            continue
        bar = ('%s<div class="panel" style="padding:9px 14px;margin:10px 0">&#128205; '
               '<strong>Location:</strong> %s</div>' % (mk, esc(loc)))
        h = h[:off] + bar + h[off:]
    return h


def pass_keysources(h, findings, _):
    """'Key sources for this verdict' before each Executive summary, verdict-bordered."""
    heads = [m for m in re.finditer(r'<(h2|h3)>Executive summary</\1>', h)]
    for m in reversed(heads):
        idx = min(len([x for x in heads if x.start() <= m.start()]) - 1, len(findings) - 1)
        f = findings[idx] if len(findings) > 1 else findings[0]
        mk = marker("keysources", project_name(f))
        if mk in h:
            continue
        links = source_links_html(f)
        if not links:
            continue
        v = verdict_of(f)
        inner = ("<h3>Key sources for this verdict</h3>"
                 '<p class="sub">Independent (non-issuer) records this verdict rests on &mdash; open them '
                 "yourself.</p><div>%s</div>" % links)
        h = h[:m.start()] + mk + panel(inner, border=VERDICT_VAR.get(v, "var(--accent)")) + h[m.start():]
    return h


def pass_timeline(h, findings, _):
    """Green-card timeline panel (required for high-unemployment projects)."""
    for i, off in insertion_points(h, findings):
        f = findings[i]
        t = f.get("timeline") or {}
        mk = marker("timeline", project_name(f))
        if mk in h or not t:
            continue
        sa = (t.get("set_aside") or "").lower()
        if sa != "high-unemployment":
            continue
        pool = t.get("visa_pool_pct", 10)
        approved = t.get("i956f_already_approved")
        rows = [
            ("Visa pool", "This is a <strong>high-unemployment</strong> project: <strong>%s%%</strong> of the "
                          "roughly 10,000 EB-5 visas a year are reserved for it, against <strong>20%%</strong> "
                          "for rural. Unused reserved visas roll into the same category next year, then into "
                          "the general pool." % esc(pool)),
            ("Priority processing", "The 2022 law directs USCIS to prioritise <strong>rural</strong> petitions. "
                                    "High-unemployment gets <strong>no such priority</strong>. This is the "
                                    "single biggest practical difference between the two."),
        ]
        if approved is True:
            rows.append(("Where it actually bites",
                         "Most of rural's speed advantage lands at the <strong>project-approval (I-956F)</strong> "
                         "stage &mdash; and <strong>this project's I-956F is already approved</strong>, so that "
                         "part of the advantage is already spent. The live difference for you is at the "
                         "<strong>I-526E</strong> (investor petition) stage. There is <strong>no</strong> "
                         "category difference at I-829."))
        else:
            rows.append(("Where it actually bites",
                         "Rural's advantage is largest at the <strong>project-approval (I-956F)</strong> stage, "
                         "which this project has <strong>not</strong> cleared &mdash; so you carry the full "
                         "difference, then again at the <strong>I-526E</strong> stage. No category difference "
                         "at I-829."))
        if t.get("i526e_stage_spread"):
            rows.append(("I-526E stage", esc(t["i526e_stage_spread"]) +
                         ' <span class="sub">(a moving number &mdash; check the current USCIS processing-times '
                         "page before you rely on it)</span>"))
        if t.get("chargeability_caveat"):
            rows.append(("Your country queue", esc(t["chargeability_caveat"])))
        if t.get("file_by"):
            rows.append(("&#9888; File by <strong>%s</strong>" % esc(t["file_by"]),
                         "The high-unemployment designation runs on a <strong>two-year window</strong> from the "
                         "I-956F filing. An investor filing after it closes can inherit an expired designation. "
                         "Treat this as a hard calendar item, and file the I-526E as early as you can &mdash; in "
                         "this category the queue only grows."))
        if t.get("notes"):
            rows.append(("Note", esc(t["notes"])))
        body = "".join(
            '<div style="margin:9px 0"><strong>%s</strong><div class="sub" style="margin-top:2px">%s</div></div>'
            % (lab, txt) for lab, txt in rows)
        inner = ("<h3>&#128197; What high-unemployment means for your green-card timeline</h3>"
                 '<p class="sub">This is a <strong>schedule</strong> disclosure, not a risk finding. Whether the '
                 "designation is <em>valid</em> is scored separately under factor I4 &mdash; what follows is only "
                 "about <em>when</em> you get your green card.</p>" + body)
        h = h[:off] + mk + panel(inner, border="var(--accent)") + h[off:]
    return h


def pass_disposition(h, findings, _):
    """Disposition chips on red flags + the 'What you can live with' panel."""
    # (a) chips inline on each red flag, matched by title
    for f in findings:
        for rf in f.get("red_flags") or []:
            d = (rf.get("disposition") or "").upper()
            if d not in DISPO_STYLE:
                continue
            title = esc(rf.get("title", ""))
            mk = marker("dispo", title[:40])
            needle = "<strong>%s</strong> <span class=\"mini\">(%s)</span>" % (title, rf.get("severity", ""))
            if mk in h or needle not in h:
                continue
            bg, fg, gloss = DISPO_STYLE[d]
            chip = ('<span style="background:%s;color:%s;font-size:10.5px;font-weight:800;letter-spacing:.04em;'
                    'padding:2px 8px;border-radius:20px;margin-left:8px">%s</span>' % (bg, fg, d))
            meta = []
            if rf.get("probability"):
                meta.append("%s %s" % (rf["probability"], PROB_TEXT.get(rf["probability"], "")))
            if rf.get("severity_class"):
                meta.append("%s %s" % (rf["severity_class"], SEV_TEXT.get(rf["severity_class"], "")))
            meta.append(gloss)
            sub = '<div class="sub" style="margin:3px 0 0 16px">%s' % esc(" &middot; ".join(meta)).replace(
                "&amp;middot;", "&middot;")
            if rf.get("basis"):
                sub += '<br><span style="opacity:.8">Basis: %s</span>' % esc(rf["basis"])
            if rf.get("mitigation"):
                sub += ('<br><span style="color:#d6a700"><strong>Ask for:</strong> %s</span>'
                        % esc(rf["mitigation"]))
            sub += "</div>"
            h = h.replace(needle, needle + mk + chip + sub, 1)

    # (b) the "What you can live with" panel
    for i, off in insertion_points(h, findings):
        f = findings[i]
        ds = f.get("decision_summary") or {}
        mk = marker("livewith", project_name(f))
        if mk in h or not ds:
            continue
        def lst(key, empty):
            items = ds.get(key) or []
            if not items:
                return '<p class="sub">%s</p>' % empty
            return '<ul style="margin:6px 0 0 18px">%s</ul>' % "".join("<li>%s</li>" % esc(x) for x in items)
        gate = ds.get("gate_class")
        gate_note = ""
        if gate == "structural":
            gate_note = ('<div class="warnbar">&#9888; <strong>Structural.</strong> This one has no fix available '
                         "to you before a decision &mdash; it is a wall, not a negotiation. %s</div>"
                         % esc(ds.get("gate_detail") or ""))
        elif gate == "curable":
            gate_note = ('<div class="warnbar">&#9888; <strong>Curable.</strong> The sponsor could still clear '
                         "this by producing what is asked for below &mdash; treat it as the opening of a "
                         "negotiation. If they will not, the refusal is itself a finding. %s</div>"
                         % esc(ds.get("gate_detail") or ""))
        one = ('<p style="font-size:15.5px;margin:0 0 4px"><strong>%s</strong></p>' % esc(ds["one_line"])) \
            if ds.get("one_line") else ""
        rv = ds.get("residual_verdict")
        rvh = ""
        if rv and rv != verdict_of(f):
            rvh = ('<p class="sub">After applying the mitigations you could realistically obtain, the residual '
                   "position is <strong>%s</strong> (the headline verdict above is unchanged &mdash; a fired hard "
                   "gate always holds it).</p>" % esc(rv))
        inner = ("<h3>What you can live with</h3>" + one + rvh + gate_note +
                 '<div class="grid g2" style="margin-top:10px">'
                 '<div style="border-left:3px solid var(--nogo);padding-left:12px">'
                 "<strong>Must clear before you wire</strong>%s</div>"
                 '<div style="border-left:3px solid var(--go);padding-left:12px">'
                 "<strong>Acceptable as-is</strong>"
                 '<p class="sub" style="margin:2px 0 0">Real, but they should <em>not</em> delay your '
                 "decision.</p>%s</div></div>" % (lst("must_clear_before_wiring", "Nothing outstanding."),
                                                  lst("acceptable_as_is", "None recorded.")))
        if ds.get("cannot_be_resolved_in_time"):
            inner += ('<div style="border-left:3px solid var(--cond);padding-left:12px;margin-top:12px">'
                      "<strong>Cannot be resolved before your deadline</strong>"
                      '<p class="sub" style="margin:2px 0 0">Proceeding means accepting these unresolved.</p>'
                      "%s</div>" % lst("cannot_be_resolved_in_time", ""))
        h = h[:off] + mk + panel(inner, border=VERDICT_VAR.get(verdict_of(f), "var(--accent)")) + h[off:]
    return h


def pass_onepager(h, findings, _):
    """Comparison one-page summary, immigration-first, from an optional `one_pager` block."""
    if marker("onepager") in h:
        return h
    op = next((f["one_pager"] for f in findings if f.get("one_pager")), None)
    if not op or len(findings) < 2:
        return h
    order = op.get("order") or [project_name(f) for f in findings]
    head = "".join("<th>%s</th>" % esc(n) for n in order)
    rows = []
    for row in op.get("rows") or []:
        cells = []
        for n in order:
            v = (row.get("values") or {}).get(n) or {}
            if isinstance(v, str):
                v = {"text": v}
            style = cell_style(v.get("text", ""), v.get("good"))
            link = ('<br><a href="%s" target="_blank" rel="noopener" style="%s">source &#8599;</a>'
                    % (esc(v["link"]), LINK)) if v.get("link") else ""
            cells.append('<td style="%s">%s%s</td>' % (style, esc(v.get("text", "-")), link))
        rows.append("<tr><td><strong>%s</strong></td>%s</tr>" % (esc(row.get("label", "")), "".join(cells)))
        if row.get("note"):
            rows.append('<tr><td colspan="%d" class="sub" style="background:rgba(91,157,255,.06)">%s</td></tr>'
                        % (len(order) + 1, esc(row["note"])))
    bottom = ""
    if op.get("bottom_line"):
        bottom = ("<h3>Bottom line</h3><ul>%s</ul>"
                  % "".join("<li>%s</li>" % esc(b) for b in op["bottom_line"]))
        if op.get("closing"):
            bottom += '<p class="sub">%s</p>' % esc(op["closing"])
    key = ('<p class="sub" style="margin:6px 0 10px">Ordered <strong>immigration-first</strong> &mdash; lowest '
           "green-card risk on the left, because de-risking the visa is the primary objective and protecting "
           "the capital comes second.<br><strong>Reading the colours:</strong> "
           '<span style="color:var(--go);font-weight:700">green</span> = genuinely good, '
           '<span style="color:var(--cond);font-weight:700">amber</span> = caution, '
           '<span style="color:var(--nogo);font-weight:700">red</span> = bad. Colour always describes the '
           "value itself, never how it compares with the other column &mdash; so a NO-GO stays red even where "
           "it is the better of the two. A thin blue bar marks the better value in a row, and a blue outline "
           "does the same in the matrix below; blue means <em>best of this set</em>, which is not the same as "
           "good.</p>")
    inner = ("<h2 style=\"margin-top:0\">One-page summary</h2>" + key +
             "<table><thead><tr><th>&nbsp;</th>%s</tr></thead><tbody>%s</tbody></table>%s"
             % (head, "".join(rows), bottom))
    block = marker("onepager") + panel(inner, border="var(--cond)")
    m = re.search(r"<h2>Summary matrix</h2>", h)
    return (h[:m.start()] + block + h[m.start():]) if m else h.replace("<footer>", block + "<footer>", 1)


def pass_questions(h, findings, _):
    """Owner-facing 1:1 questions, each with What this means / Why it matters."""
    if marker("questions") in h:
        return h
    blocks = []
    for f in findings:
        qs = f.get("questions")
        if not qs:
            qs = [{"q": "You list this as an open item: %s. What is the documentary answer, and can I have the "
                        "underlying record?" % g.get("item", g) if isinstance(g, dict) else str(g),
                   "means": "You are asking them to close a gap this review could not close from public sources.",
                   "matters": "An owner who can answer from documents on the spot is a different counterparty "
                              "from one who cannot."}
                  for g in (f.get("data_gaps") or [])[:12]]
        if not qs:
            continue
        items = []
        for q in qs:
            if isinstance(q, str):
                q = {"q": q}
            link = ""
            si = q.get("source_index")
            srcs = f.get("sources") or []
            if isinstance(si, int) and 1 <= si <= len(srcs) and srcs[si - 1].get("url"):
                link = ('&nbsp;<a href="%s" target="_blank" rel="noopener" style="%s">source &#8599;</a>'
                        % (esc(srcs[si - 1]["url"]), LINK))
            sub = ""
            if q.get("means"):
                sub += "<div><strong>What this means:</strong> %s</div>" % esc(q["means"])
            if q.get("matters"):
                sub += "<div><strong>Why it matters:</strong> %s</div>" % esc(q["matters"])
            items.append(
                '<div style="margin:12px 0"><div><strong>%s</strong>%s</div>'
                '<div class="sub" style="border-left:2px solid var(--line);padding-left:10px;margin-top:4px">'
                "%s</div></div>" % (esc(q["q"]), link, sub))
        loc = location_str(f)
        blocks.append('<details class="acc"><summary>%s%s &mdash; <span class="chip" style="font-size:11px;'
                      'padding:2px 8px;background:%s;color:#fff">%s</span></summary><div class="body">%s</div>'
                      "</details>"
                      % (esc(project_name(f)), (" &middot; " + esc(loc.split(",")[-2].strip() + ", " +
                                                                   loc.split(",")[-1].strip()))
                         if loc.count(",") >= 1 else "",
                         VERDICT_VAR.get(verdict_of(f), "var(--accent)"), esc(verdict_of(f)), "".join(items)))
    if not blocks:
        return h
    block = (marker("questions") + "<h2>Questions to ask in your 1:1</h2>" +
             '<p class="sub">Built from what this review could <em>not</em> verify. Each one has a documentary '
             "answer &mdash; ask for the document, not the reassurance. How readily it is produced tells you as "
             "much as the answer.</p>" + "".join(blocks))
    return h.replace("<footer>", block + "<footer>", 1)


def pass_jargon(h, findings, _):
    """Inline clickable info icons on jargon. MUST run last.

    Guards (each one has bitten before):
      * split on tags and wrap only text nodes -- never inside <style>/<script>/<a>/
        headings/<summary>, or the CSS and links get corrupted;
      * the tag-name regex must not swallow the trailing '>';
      * one longest-match-first substitution per text node, so injected markup is not
        re-scanned;
      * (?<![\\w-]) / (?![\\w-]) boundaries so terms don't match inside other words;
      * the definition is .ji-pop text content -- HTML-escape it, keep it plain.
    """
    if marker("jargon") in h:
        return h
    terms = load_asset("report-glossary.json")["terms"]
    if not terms:
        return h

    skip_tags = {"style", "script", "a", "h1", "h2", "summary", "button", "title", "code", "option", "textarea"}
    ordered = sorted(terms, key=len, reverse=True)
    pat = re.compile(r"(?<![\w-])(" + "|".join(re.escape(t) for t in ordered) + r")(?![\w-])")
    seen = set()

    def wrap(m):
        term = m.group(1)
        if term in seen:
            return term
        seen.add(term)
        return ('<span class="jt">%s<button type="button" class="ji" aria-label="What is %s?">i</button>'
                '<span class="ji-pop" role="tooltip">%s</span></span>'
                % (term, esc(term), esc(terms[term])))

    parts = re.split(r"(<[^>]+>)", h)
    depth = 0
    out = []
    for seg in parts:
        if seg.startswith("<"):
            mt = re.match(r"</?\s*([A-Za-z][\w-]*)", seg)   # must NOT capture the trailing '>'
            if mt:
                tag = mt.group(1).lower()
                if tag in skip_tags:
                    if seg.startswith("</"):
                        depth = max(0, depth - 1)
                    elif not seg.rstrip().endswith("/>"):
                        depth += 1
            out.append(seg)
        else:
            out.append(seg if (depth or not seg.strip()) else pat.sub(wrap, seg, count=1))
    h = "".join(out)

    tip = ('%s<p class="sub">&#9432; Tap the small <strong>i</strong> next to any term for a plain-language '
           "definition &mdash; no jargon assumed.</p>" % marker("jargon"))
    m = re.search(r"<h2>", h)
    return (h[:m.start()] + tip + h[m.start():]) if m else tip + h


PASS_FUNCS = {
    "heatmap": pass_heatmap, "srcdocs": pass_srcdocs, "location": pass_location,
    "keysources": pass_keysources, "timeline": pass_timeline, "disposition": pass_disposition,
    "onepager": pass_onepager, "questions": pass_questions, "jargon": pass_jargon,
}


def main(argv=None):
    ap = argparse.ArgumentParser(description="Apply the EB-5 house format to a rendered report.")
    ap.add_argument("--html", required=True, help="Rendered HTML from render_report.ps1.")
    ap.add_argument("--findings", required=True,
                    help="findings.json, or a comma-separated list in the SAME order as -Findings.")
    ap.add_argument("--out", help="Output path (default: in place).")
    ap.add_argument("--only", help="Comma-separated subset of passes to run.")
    ap.add_argument("--skip", help="Comma-separated passes to skip.")
    a = ap.parse_args(argv)

    src = pathlib.Path(a.html)
    h = src.read_text(encoding="utf-8")
    findings = [json.loads(pathlib.Path(p.strip()).read_text(encoding="utf-8"))
                for p in a.findings.split(",") if p.strip()]

    run = [p for p in PASSES if p in set((a.only or ",".join(PASSES)).split(","))]
    run = [p for p in run if p not in set((a.skip or "").split(","))]
    if "jargon" in run:                      # always last
        run = [p for p in run if p != "jargon"] + ["jargon"]

    before = len(h)
    applied = []
    for name in run:
        n0 = len(h)
        h = PASS_FUNCS[name](h, findings, a)
        if len(h) != n0:
            applied.append(name)

    dst = pathlib.Path(a.out or a.html)
    dst.write_text(h, encoding="utf-8")
    print("enhanced %s -> %s (%d -> %d chars)" % (src.name, dst.name, before, len(h)))
    print("applied: %s" % (", ".join(applied) or "nothing (already enhanced?)"))
    skipped = [p for p in run if p not in applied]
    if skipped:
        print("no-op:   %s" % ", ".join(skipped))
    return 0


if __name__ == "__main__":
    sys.exit(main())
