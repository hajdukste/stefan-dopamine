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
mat_file_has_two_regions = False
mat_region_order = ("NAcLat", "NAcMed")
add_csv_as_second_region = True
csv_region = "NAcMed"
processed_output_folder = None
show_overview_plot = False
```

```bash
/opt/anaconda3/envs/py312/bin/python a00_get_data.py
/opt/anaconda3/envs/py312/bin/python a02_session_heatmap_psth.py
```

Command-line arguments are still available as temporary overrides, but the
intended workflow is to edit the script header just like the MATLAB version.

Common `a02_session_heatmap_psth.py` header settings:

```python
processed_data_folder = None
animal_index = 1
day_index = 1
view_mode = "single"
plot_two_regions = True
heatmap_colormap = "parula_like"
heatmap_value_limits = None
save_figure_path = None
show_figure = True
```

`a00_get_data.py` also has `DAY_MAP` and `ANIMAL_MAP` near the top. `DAY_MAP`
maps filename dates to numeric day indices, for example `"04092026": 1`. If a
date is not listed, the script prints a warning and saves `day_index` as
`None`; add the date to `DAY_MAP` before using `a02` day selection. If an
animal is not listed, the script prints a warning and keeps the raw animal name
from the filename.

Processed outputs are written to `processed/<session-name>/` by default.
