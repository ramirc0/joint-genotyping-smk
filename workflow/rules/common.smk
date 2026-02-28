from pathlib import Path
from pprint import pprint

CALLSET_NAME=config["input"].get("callset_name")
def scatter_lookup(wildcards):
  SCATTER_LOOKUP = dict(zip(
      [str(i) for i in range(config["params"].get("scatter_count"))],
      [f"results/scatter_dir/{i:04d}-scattered.interval_list" for i in range(config["params"].get("scatter_count"))]
  ))
  return SCATTER_LOOKUP[wildcards.scatter]

def gather_sites_only_vcfs_signals():
  scatter_range = range(config["params"].get("scatter_count"))
  return { 
    "signal": [f"results/hard_filter/{scatter}.ok" for scatter in scatter_range],
  }

def gather_score_variant_annotations_signals():
  scatter_range = range(config["params"].get("scatter_count"))
  return { 
    "signal": [f"results/score_variant_annotations/{scatter}.ok" for scatter in scatter_range],
  }
