#!/usr/bin/env python3

import pandas as pd
import argparse

#########################################################
# ARGUMENTS
#########################################################

parser = argparse.ArgumentParser()

parser.add_argument("--sample", required=True)

parser.add_argument("--tool1", required=True)
parser.add_argument("--tool2", required=True)
parser.add_argument("--tool3", required=True)

parser.add_argument("--centromere", required=True)

args = parser.parse_args()

sample = args.sample

#########################################################
# TOOL 1 (HEADERLESS FILE)
#########################################################

tool1_header = [
    "type",
    "region",
    "size",
    "Ratio",
    "e-val1",
    "e-val2",
    "e-val3",
    "e-val4",
    "q0",
    "pN",
    "dG"
]

df = pd.read_csv(
    args.tool1,
    sep="\t",
    header=None,
    names=tool1_header
)

# Split region
df[["chrom", "coords"]] = df["region"].str.split(":", expand=True)
df[["start", "end"]] = df["coords"].str.split("-", expand=True)

# Convert types
df["start"] = df["start"].astype(int)
df["end"] = df["end"].astype(int)

# Ratio -> CN
df["CN"] = (2 * df["Ratio"]).round(0).astype(int)

# CN Type
df["CN_type"] = df["type"].map({
    "deletion": "DEL",
    "duplication": "DUP"
})

df["Tool"] = 1
df["sub_CNtype"] = "Not_Defined"

out1 = df[[
    "chrom",
    "start",
    "end",
    "CN",
    "CN_type",
    "size",
    "sub_CNtype",
    "Tool"
]]

#########################################################
# TOOL 2
#########################################################

df = pd.read_csv(args.tool2, sep="\t")

df = df[df["Corrected_Call"] != "NEUT"]

mask = df["Corrected_Call"] == "HLAMP"

df.loc[mask, "Corrected_Copy_Number"] = (
    2 * (2 ** df.loc[mask, "seg.median.logR"])
).round().astype(int)

df.loc[
    mask & (df["Corrected_Copy_Number"] == 1),
    "Corrected_Call"
] = "HETD"

df.loc[
    mask & (df["Corrected_Copy_Number"] == 0),
    "Corrected_Call"
] = "HOMD"

df.rename(columns={
    "Corrected_Call": "sub_CNtype",
    "Corrected_Copy_Number": "CN"
}, inplace=True)

df["size"] = abs(df["end"] - df["start"]) + 1

df["Tool"] = 2

def classify_cn(cn):

    if cn < 2:
        return "DEL"

    elif cn > 2:
        return "DUP"

    else:
        return "NEUT"

df["CN_type"] = df["CN"].apply(classify_cn)

out2 = df[[
    "chrom",
    "start",
    "end",
    "CN",
    "CN_type",
    "size",
    "sub_CNtype",
    "Tool"
]]

#########################################################
# TOOL 3
#########################################################

df = pd.read_csv(args.tool3, sep="\t")

df.rename(columns={
    "chromosome": "chrom",
    "cn": "CN"
}, inplace=True)

def classify_cn(cn):
    if cn < 2:
        return "DEL"
    elif cn > 2:
        return "DUP"
    else:
        return "NEUT"

df["CN_type"] = df["CN"].apply(classify_cn)

df = df[df["CN_type"] != "NEUT"]

df["start"] = df["start"] + 1

df["size"] = abs(df["end"] - df["start"]) + 1

df["Tool"] = 3
df["sub_CNtype"] = "Not_Defined"

out3 = df[[
    "chrom",
    "start",
    "end",
    "CN",
    "CN_type",
    "size",
    "sub_CNtype",
    "Tool"
]]

#########################################################
# COMBINE
#########################################################

final = pd.concat(
    [out1, out2, out3],
    ignore_index=True
)

final = final.sort_values(
    ["chrom", "start"]
)

#########################################################
# CENTROMERE / NO-GENE REGION FILTER
#########################################################

centromere_df = pd.read_csv(
    args.centromere,
    sep="\t",
    names=["chr", "start", "end", "type"]
)

def tag_centromere_for_final(row, centromere_regions):
    cnv_chr = row['chrom']
    cnv_start = row['start']
    cnv_end = row['end']

    chrom_centromeres = centromere_regions[centromere_regions['chr'] == cnv_chr]
    overlapping_types = set()

    for _, centro_row in chrom_centromeres.iterrows():
        centro_start = centro_row['start']
        centro_end = centro_row['end']

        if max(cnv_start, centro_start) < min(cnv_end, centro_end):
            overlapping_types.add(centro_row['type'])

    if overlapping_types:
        return ",".join(sorted(list(overlapping_types)))
    return "Independent_of_Centromere_NoGene"

final["Centromere_Status"] = final.apply(lambda row: tag_centromere_for_final(row, centromere_df), axis=1)

final = final[~final['Centromere_Status'].isin(['centromere', 'no_genes'])]
final = final.drop(columns=['Centromere_Status'])

#########################################################
# GROUP DUPLICATE CALLS (SAME REGION, MULTIPLE TOOLS)
#########################################################

df_record_merged = (
    final
    .groupby(["chrom", "start", "end", "CN", "CN_type"], as_index=False)
    .agg({
        "size": "first",  # size will be same, so just take one
        "Tool": lambda x: ",".join(map(str, sorted(set(x))))
    })
)

#########################################################
# MERGE OVERLAPPING/ADJACENT CALLS OF THE SAME TYPE
#########################################################

def merge_overlapping_cnvs(df):
    if df.empty:
        return df

    # Ensure the dataframe is sorted by chromosome, CN_type, CN, start, and end.
    # Sorting by CN_type and CN first ensures that only regions with identical call types
    # are considered for merging.
    df = df.sort_values(by=['chrom', 'CN_type', 'CN', 'start', 'end']).reset_index(drop=True)

    merged_records = []
    current_chrom = None
    current_cn_type = None
    current_cn = None
    current_start = None
    current_end = None
    current_tools = set()

    for index, row in df.iterrows():
        # Initialize for the first record or when a new group (chrom, CN_type, CN) begins
        if (current_chrom is None or
            row['chrom'] != current_chrom or
            row['CN_type'] != current_cn_type or
            row['CN'] != current_cn):

            # If there was a previous merged record, add it to the list
            if current_chrom is not None:
                merged_records.append({
                    'chrom': current_chrom,
                    'start': current_start,
                    'end': current_end,
                    'CN': current_cn,
                    'CN_type': current_cn_type,
                    'size': current_end - current_start + 1,
                    'Tool': ",".join(map(str, sorted(list(current_tools))))
                })

            # Start a new merged record with the current row's data
            current_chrom = row['chrom']
            current_cn_type = row['CN_type']
            current_cn = row['CN']
            current_start = row['start']
            current_end = row['end']
            # Convert tool string "1,3" to a set of integers {1, 3}
            current_tools = set(map(int, str(row['Tool']).split(',')))

        # If the current record overlaps or is immediately adjacent to the 'current_merged_interval'
        # and has the same chrom, CN_type, and CN
        elif row['start'] <= current_end + 1: # +1 to also merge adjacent regions
            current_end = max(current_end, row['end'])
            # Add tools from the overlapping/adjacent region
            current_tools.update(set(map(int, str(row['Tool']).split(','))))
        else:
            # No overlap or adjacency, so the 'current_merged_interval' is complete
            merged_records.append({
                'chrom': current_chrom,
                'start': current_start,
                'end': current_end,
                'CN': current_cn,
                'CN_type': current_cn_type,
                'size': current_end - current_start + 1,
                'Tool': ",".join(map(str, sorted(list(current_tools))))
            })

            # Start a new merged record with the current row's data
            current_chrom = row['chrom']
            current_cn_type = row['CN_type']
            current_cn = row['CN']
            current_start = row['start']
            current_end = row['end']
            current_tools = set(map(int, str(row['Tool']).split(',')))

    # Add the last merged record after the loop finishes
    if current_chrom is not None:
        merged_records.append({
            'chrom': current_chrom,
            'start': current_start,
            'end': current_end,
            'CN': current_cn,
            'CN_type': current_cn_type,
            'size': current_end - current_start + 1,
            'Tool': ",".join(map(str, sorted(list(current_tools))))
        })

    merged_df = pd.DataFrame(merged_records)
    # Ensure correct column order, same as input df_record_merged
    merged_df = merged_df[['chrom', 'start', 'end', 'CN', 'CN_type', 'size', 'Tool']]
    return merged_df

# Apply the merging function to df_record_merged
df_final_merged = merge_overlapping_cnvs(df_record_merged.copy())

# Keep original (bp) and add conversions
df_final_merged["size_kb"] = (df_final_merged["size"] / 1e3).round(2)
df_final_merged["size_mb"] = (df_final_merged["size"] / 1e6).round(3)
df_final_merged = df_final_merged.drop(columns=["size"])

output_file = f"{sample}_merged_cnvs.csv"

df_final_merged.to_csv(output_file, index=False)

print(f"Merged CNVs saved to {output_file}")
