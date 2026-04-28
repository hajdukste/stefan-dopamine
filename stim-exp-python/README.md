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

```bash
/opt/anaconda3/envs/py312/bin/python a00_get_data.py
/opt/anaconda3/envs/py312/bin/python a02_session_heatmap_psth.py --two-signals --no-show --save session_psth.png
```

Processed outputs are written to `processed/<session-name>/` by default.
