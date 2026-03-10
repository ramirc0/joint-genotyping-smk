import polars as pl

def main():
    ( 
        pl
        .read_csv("./MOHD.Phase_0_Samples.tsv", separator="\t")
        .filter(pl.col("data_modality") == "WGS")
        .with_columns(
            pl.col("entity:dataset_id").str.strip_chars_start("MOHD_").alias("mohd_accession"),
        )
        .select(
            "mohd_accession",
            pl.format("/data/zusers/ramirezc/wgs-smk/results/reblock/{}.rb.g.vcf.gz", "mohd_accession").alias("gvcf"),
        )
        .sort("mohd_accession")
        .write_csv("./MOHD.sample_map.tsv", separator="\t", include_header=False)
    )

if __name__ == "__main__":
    main()
