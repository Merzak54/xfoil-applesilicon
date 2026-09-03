#!/usr/bin/env python3
"""RF Doc web application.

    python3 webapp.py            # then open http://127.0.0.1:5000

Browser form for the Site Build Form; generates <SITE_ID>_RFDOC.xlsx for download
and can pre-fill itself from an existing RF Doc (.xlsx) or JSON file.
"""

from __future__ import annotations

import copy
import io
import json
import tempfile
from pathlib import Path

from flask import Flask, flash, redirect, render_template, request, send_file, url_for

from rfdoc import EXAMPLE, SECTOR_FIELDS, SECTORS, SITE_FIELDS, dump, fill

app = Flask(__name__)
app.secret_key = "rfdoc-local"
app.config["MAX_CONTENT_LENGTH"] = 5 * 1024 * 1024


def _empty() -> dict:
    return {
        **{k: "" for k in SITE_FIELDS},
        "sectors": {s: {k: "" for k in SECTOR_FIELDS} for s in SECTORS},
    }


def _from_form(form) -> dict:
    d = {k: form.get(k, "").strip() for k in SITE_FIELDS}
    d["sectors"] = {
        s: {k: form.get(f"{s}.{k}", "").strip() for k in SECTOR_FIELDS} for s in SECTORS
    }
    return d


def _merge(d: dict) -> dict:
    out = _empty()
    out.update({k: str(d.get(k, "")) for k in SITE_FIELDS})
    for s in SECTORS:
        out["sectors"][s].update(
            {
                k: str(v)
                for k, v in d.get("sectors", {}).get(s, {}).items()
                if k in SECTOR_FIELDS
            }
        )
    return out


@app.get("/")
def index():
    return render_template(
        "form.html",
        data=copy.deepcopy(EXAMPLE),
        site_fields=SITE_FIELDS,
        sector_fields=SECTOR_FIELDS,
        sectors=SECTORS,
    )


@app.post("/")
def render_form():
    if "generate" in request.form:
        data = _from_form(request.form)
        buf = io.BytesIO()
        with tempfile.NamedTemporaryFile(suffix=".xlsx") as tmp:
            fill(data, Path(tmp.name))
            buf.write(Path(tmp.name).read_bytes())
        buf.seek(0)
        name = f"{data['site_id'] or 'SITE'}_RFDOC.xlsx"
        return send_file(
            buf,
            as_attachment=True,
            download_name=name,
            mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )

    data = _from_form(request.form)
    if "clear" in request.form:
        data = _empty()
    elif "example" in request.form:
        data = copy.deepcopy(EXAMPLE)
    elif "load" in request.form:
        f = request.files.get("file")
        if not f or not f.filename:
            flash("Choose an .xlsx or .json file to load.")
            return redirect(url_for("index"))
        try:
            if f.filename.lower().endswith(".json"):
                data = _merge(json.loads(f.read().decode("utf-8")))
            else:
                with tempfile.NamedTemporaryFile(suffix=".xlsx") as tmp:
                    f.save(tmp.name)
                    data = _merge(dump(Path(tmp.name)))
            flash(f"Loaded {f.filename}")
        except Exception as exc:  # noqa: BLE001 - surface any parse error to the user
            flash(f"Could not read {f.filename}: {exc}")
    return render_template(
        "form.html",
        data=data,
        site_fields=SITE_FIELDS,
        sector_fields=SECTOR_FIELDS,
        sectors=SECTORS,
    )


if __name__ == "__main__":
    app.run(host="127.0.0.1", port=5000, debug=False)
