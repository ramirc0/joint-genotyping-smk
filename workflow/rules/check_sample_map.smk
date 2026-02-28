rule check_sample_map:
  input:
    sample_map=config["input"].get("sample_map"),
  output:
    singal=touch("results/sample_map.ok"),
  params:
    sample_num_threshold=config["params"].get("sample_num_threshold", 50),
  log: "logs/check_sample_map.log"
  run: 
    import os
    import sys

    log_fh = open(log[0], "w")
    sys.stdout = log_fh
    sys.stderr = log_fh

    try:
      import polars as pl
    except ImportError:
      raise ImportError("Please ensure that polars is installed to the environment.")

    sample_map_df = pl.read_csv(input.sample_map, separator="\t", has_header=False, new_columns=["sample_id", "gvcf"])
    assert all(map(lambda x: os.path.exists(x), sample_map_df["gvcf"])), "All GVCFs must exist."
    assert len(sample_map_df["sample_id"]) == len(sample_map_df["sample_id"].unique()), "Sample IDs must be unique."
    assert sample_map_df.height > params.sample_num_threshold, "Sample map must have more than 50 samples for joint genotyping."
    print("Sample map is valid.")
    log_fh.close()
