#!/usr/bin/env python3
"""
Convert the unified/merged CNV calls (output of merge_cnvs.py) into a BED
file formatted for AnnotSV.

Expected columns in the input csv: chrom,start,end,CN,CN_type,Tool,size_kb,size_mb
Output BED columns (1-indexed for AnnotSV): chr,start,end,svtype,sample_id,CN
    -> svtBEDcol 4, samplesidBEDcol 5
"""

import argparse
import pandas as pd

parser = argparse.ArgumentParser()
parser.add_argument("--input", required=True, help="merged CNV csv from merge_cnvs.py")
parser.add_argument("--sample", required=True)
parser.add_argument("--output", required=True, help="output BED path")
args = parser.parse_args()

df = pd.read_csv(args.input)

required_cols = {"chrom", "start", "end", "CN", "CN_type"}
missing = required_cols - set(df.columns)
if missing:
    raise SystemExit(f"Missing required columns in input: {sorted(missing)}")

bed_df = pd.DataFrame({
    "chr": df["chrom"],
    "start": df["start"].astype(int),
    "end": df["end"].astype(int),
    "svtype": df["CN_type"],
    "sample_id": args.sample,
    "CN": df["CN"],
})

bed_df.to_csv(args.output, sep="\t", index=False)

print(f"BED file written to {args.output}")
print(f"Total CNVs written: {len(bed_df)}")
