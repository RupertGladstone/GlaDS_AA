
# Elmer/GlaDS simulated Antarctic subglacial hydrology

Citation for this repo is Zhao et al., 2025 in Nature Comms <br>
https://www.nature.com/articles/s41467-025-58375-4

Supporting data here: <br>
https://zenodo.org/records/14874036

The current .vtu file adds combined channel and distributed fluxes across the grounding line. This was processed within the Elmer framework.

The script process_glads_gl.py is designed to give a list of primary subglacial outflow locations and their coordinates.

## Running the script

### Dependencies
The script requires `meshio` and `pyproj`. Install via conda:
```bash
conda install -c conda-forge meshio pyproj
```

### Basic usage
```bash
python process_glads_gl.py GlaDS_AA_V1_0.vtu
```

This selects the 500 nodes with the highest grounding line flux, converts units from m³/yr to m³/s, and writes results to `GlaDS_AA_V1_0_gl_outflow.txt` in the same directory.

### Optional: custom threshold
```bash
python process_glads_gl.py GlaDS_AA_V1_0.vtu --threshold 10.0
```

Overrides the default 500-node cutoff with a fixed flux threshold in m³/s.

### Output columns
`gl_flux(m3/s)  gl_flux_scaled(m3/s)  x_3031(m)  y_3031(m)  lat(deg)  lon(deg)`

The scaled flux column multiplies each value so that the selected nodes collectively represent 100% of the total grounding line outflow.

