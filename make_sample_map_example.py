import polars as pl

def main():
    available_samples_df = (
        pl
        .read_csv("./MOHD.Phase_0_Samples.tsv", separator="\t")
        .filter(pl.col("data_modality") == "WGS")
    )
    mohd_accessions = available_samples_df["entity:dataset_id"].sort().to_list()
    reblocked_gvcf_format = "/data/zusers/ramirezc/wgs-smk/results/reblock/{}.rb.g.vcf.gz" # NOTE: Output of wgs-smk pipeline
    reblocked_gvcf_files = [reblocked_gvcf_format.format(acc.lstrip("MOHD_")) for acc in mohd_accessions]
    pl.DataFrame({"mohd_accession": mohd_accessions, "gvcf": reblocked_gvcf_files}).write_csv("MOHD.sample_map.tsv", separator="\t", include_header=False)

if __name__ == "__main__":
    main()
