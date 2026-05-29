#!/usr/bin/env python3
"""
Extract grounding line nodes with high subglacial outflow from a GlaDS VTU file.

Usage:
    python3 process_glads_gl.py <vtu_file> [--threshold VALUE]

Output (same directory as VTU file):
    <basename>_gl_outflow.txt
    Columns: magnitude  x_3031(m)  y_3031(m)  lat(deg)  lon(deg)

Coordinates are assumed to be ISMIP6/7 Antarctic Polar Stereographic (EPSG:3031).
"""

import argparse
import os
import sys
import numpy as np
import meshio
from pyproj import Transformer


def main():
    parser = argparse.ArgumentParser(
        description='Extract high-outflow grounding line nodes from a GlaDS VTU file.'
    )
    parser.add_argument('vtu_file', help='Path to input VTU file')
    parser.add_argument(
        '--threshold', type=float, default=None,
        metavar='VALUE',
        help='Minimum sheet discharge magnitude to include. '
             'Defaults to the 100th-largest value among grounding line nodes.'
    )
    args = parser.parse_args()

    vtu_path = os.path.abspath(args.vtu_file)
    if not os.path.exists(vtu_path):
        sys.exit(f'Error: file not found: {vtu_path}')

    out_dir = os.path.dirname(vtu_path)
    basename = os.path.splitext(os.path.basename(vtu_path))[0]
    out_path = os.path.join(out_dir, basename + '_gl_outflow.txt')

    print(f'Reading {vtu_path} ...')
    mesh = meshio.read(vtu_path)

    points = mesh.points                              # (N, 3): x, y in EPSG:3031, z = elevation
    groundedmask   = mesh.point_data['groundedmask']  # scalar per node
    gl_flux = mesh.point_data['gl flux']                  # scalar per node

    # Grounding line: groundedmask exactly == 0
    gl_mask    = groundedmask == 0
    gl_indices = np.where(gl_mask)[0]
    print(f'Grounding line nodes (groundedmask == 0): {len(gl_indices)}')

    if len(gl_indices) == 0:
        sys.exit('No grounding line nodes found.')

    gl_points = points[gl_indices]

    # Convert m³/yr -> m³/s
    SECONDS_PER_YEAR = 365.25 * 24 * 3600
    magnitude = gl_flux[gl_indices] / SECONDS_PER_YEAR

    # Determine threshold (in m³/s, after conversion)
    if args.threshold is not None:
        threshold = args.threshold
        print(f'Using user-specified threshold: {threshold:.6g} m³/s')
    else:
        n_top = 500
        if len(magnitude) <= n_top:
            threshold = magnitude.min()
            print(f'Fewer than {n_top} grounding line nodes; using all ({len(magnitude)}).')
        else:
            threshold = np.partition(magnitude, -n_top)[-n_top]
            print(f'Auto threshold (500th-largest value): {threshold:.6g} m³/s')

    above        = magnitude >= threshold
    sel_indices  = gl_indices[above]
    sel_points   = points[sel_indices]
    sel_magnitude = magnitude[above]

    total_outflow    = magnitude.sum()
    selected_outflow = sel_magnitude.sum()
    pct = 100.0 * selected_outflow / total_outflow if total_outflow > 0 else 0.0
    scale_factor = 100.0 / pct if pct > 0 else 1.0
    scaled_magnitude = sel_magnitude * scale_factor

    print(f'Nodes at or above threshold: {above.sum()}')
    print(f'Selected outflow as % of total grounding line outflow: {pct:.1f}%')
    print(f'Scale factor applied to flux values: {scale_factor:.4f}')

    # Convert EPSG:3031 (x, y) -> WGS84 lat/lon
    transformer = Transformer.from_crs('EPSG:3031', 'EPSG:4326', always_xy=True)
    lon, lat = transformer.transform(sel_points[:, 0], sel_points[:, 1])

    # Sort by descending magnitude for readability
    order = np.argsort(sel_magnitude)[::-1]

    with open(out_path, 'w') as f:
        f.write('# GlaDS grounding line outflow nodes\n')
        f.write(f'# Source: {os.path.basename(vtu_path)}\n')
        f.write(f'# Threshold: {threshold:.6g} m³/s\n')
        f.write(f'# Scale factor (to represent 100% of grounding line outflow): {scale_factor:.4f}\n')
        f.write('# Columns: gl_flux(m3/s)  gl_flux_scaled(m3/s)  x_3031(m)  y_3031(m)  lat(deg)  lon(deg)\n')
        for i in order:
            f.write(
                f'{sel_magnitude[i]:.6e}  '
                f'{scaled_magnitude[i]:.6e}  '
                f'{sel_points[i, 0]:.3f}  '
                f'{sel_points[i, 1]:.3f}  '
                f'{lat[i]:.6f}  '
                f'{lon[i]:.6f}\n'
            )

    print(f'Written {above.sum()} lines to {out_path}')


if __name__ == '__main__':
    main()
