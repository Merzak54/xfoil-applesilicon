# RF Doc generator

Fills the `Site Build Form` sheet (`RFDOC_template.xlsx`, layout taken from
`BM1183_RFDOC.xlsx`) with site and per-sector RF data and writes
`<SITE_ID>_RFDOC.xlsx`. Styles, merged cells and the logo are preserved.

```sh
pip install openpyxl pillow

python3 rfdoc.py --gui                     # Tk form, pre-filled with the BM1183 values
python3 rfdoc.py                           # same, as terminal prompts
python3 rfdoc.py --example > site.json     # edit, then:
python3 rfdoc.py --json site.json          # -> BM1183_RFDOC.xlsx
python3 rfdoc.py --dump BM1183_RFDOC.xlsx  # existing RF Doc -> JSON
```

Fields: site_id, site_address, east, north, rbs_type, bsc_rnc, comments,
rp_engineer, rp_manager, phone, date, and per sector (A/B/C): azimuth,
antenna_model, n_antennas, hba, building_height, tower_height, mech_tilt,
etilt_900, etilt_1800, etilt_2100, trx.
