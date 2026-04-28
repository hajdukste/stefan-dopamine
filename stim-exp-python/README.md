# stefan-dopamine

Python port of the stimulation experiment analysis scripts from the MATLAB
workspace.

## Contents

- `a00_get_data.py`: load raw FIP data, process TTL events, optionally align
  the second CSV signal, and save processed Parquet tables plus metadata.
- `a02_session_heatmap_psth.py`: load processed sessions and plot heatmaps and
  PSTHs.
- `fipster_io.py`: thin loader wrapper around vendored GitHub Fipster Python,
  with a local fallback parser for the MATLAB formats used here.
- `vendor/Fipster_python`: vendored from
  `https://github.com/handejong/Fipster`; see
  `vendor/Fipster_python/UPSTREAM.md` for the pinned commit.

## Setup

```bash
/opt/anaconda3/envs/py312/bin/python -m pip install -r requirements.txt
```

## Example

Edit the parameter block at the top of `a00_get_data.py`, then run the whole
file:

```python
input_mat_file = "..."
csv_export_parent_folder = "..."
main_file_has_two_regions = False
add_csv_as_second_region = True
processed_output_folder = None
show_overview_plot = False
```

```bash
/opt/anaconda3/envs/py312/bin/python a00_get_data.py
/opt/anaconda3/envs/py312/bin/python a02_session_heatmap_psth.py --two-signals --no-show --save session_psth.png
```

Command-line arguments are still available as temporary overrides, but the
intended workflow is to edit the script header just like the MATLAB version.

Processed outputs are written to `processed/<session-name>/` by default.
