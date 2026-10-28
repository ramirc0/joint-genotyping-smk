# Config, sample map, and shared helpers.

import json
from pathlib import Path

import polars as pl
from snakemake.exceptions import WorkflowError


configfile: "config/config.yaml"


RUN_ID = config.get("run_id", "default")
OUTDIR = f"{config['outdir']}/{RUN_ID}"
LOGDIR = f"logs/{RUN_ID}"
BENCHDIR = f"benchmarks/{RUN_ID}"
REFS = config["references"]
CALLSET = config["callset_name"]

REFERENCE = {
    "fasta": REFS["fasta"],
    "fasta_index": f"{REFS['fasta']}.fai",
    "fasta_dict": str(Path(REFS["fasta"]).with_suffix(".dict")),
}

SCATTER_DIGITS = max(4, len(str(config["scatter_count"] - 1)))
SCATTERS = [f"{i:0{SCATTER_DIGITS}d}" for i in range(config["scatter_count"])]
SCATTERED_INTERVAL_LIST = f"{OUTDIR}/scatter_dir/{{scatter}}-scattered.interval_list"

VETS_RESOURCES = {
    "hapmap,training=true,calibration=true": REFS["hapmap_resource_vcf"],
    "omni,training=true,calibration=true": REFS["omni_resource_vcf"],
    "1000G,training=true": REFS["one_thousand_genomes_resource_vcf"],
    "mills,training=true,calibration=true": REFS["mills_resource_vcf"],
}
VETS_RESOURCE_ARGS = [
    token
    for label, vcf in VETS_RESOURCES.items()
    for token in (f"--resource:{label}", vcf)
]
VETS_MODEL = expand(
    f"{OUTDIR}/{CALLSET}.train.{{mode}}.{{file}}",
    mode=["snp", "indel"],
    file=["scorer.pkl", "trainingScores.hdf5", "calibrationScores.hdf5"],
)

# The workspace path is relative to the rule file. Every rule file sits in rules/.
SOFTWARE_ENV = pixi(workspace="../envs", env=config["pixi_env"], locked=True)
GATK_ENV = pixi(workspace="../envs", env="gatk", locked=True)


SAMPLE_MAP = config["sample_map"]
if not Path(SAMPLE_MAP).exists():
    raise WorkflowError(
        f"Sample map not found: {SAMPLE_MAP}\n"
        "Headerless TSV of sample ID and gVCF path; see config/sample_map.example.tsv."
    )

_sample_map = pl.read_csv(
    SAMPLE_MAP, separator="\t", has_header=False, new_columns=["sample_id", "gvcf"]
)
if not all(Path(gvcf).exists() for gvcf in _sample_map["gvcf"]):
    raise WorkflowError("All GVCFs must exist.")
if _sample_map["sample_id"].n_unique() != _sample_map.height:
    raise WorkflowError("Sample IDs must be unique.")
if _sample_map.height < config["sample_num_threshold"]:
    raise WorkflowError(
        f"Sample map has {_sample_map.height} samples; joint genotyping needs at least "
        f"{config['sample_num_threshold']}."
    )


wildcard_constraints:
    scatter=r"\d+",


def repeat_flag(flag, values):
    """Return `flag` before each value, as one token list.

    Parameters
    ----------
    flag : str
        Command-line flag, such as `-A` or `--input`.
    values : iterable
        Values to pass. Each is converted with `str`.

    Returns
    -------
    list of str
        `[flag, value1, flag, value2, ...]`. Interpolate it with `:q`.
    """
    return [token for value in values for token in (flag, str(value))]


def notify_slack(text):
    """Post `text` to `config["slack_webhook_url"]` when one is set.

    Parameters
    ----------
    text : str
        Message body.
    """
    url = config.get("slack_webhook_url", None)
    if url:
        payload = json.dumps({"text": text}, ensure_ascii=False)
        shell("curl -X POST -H 'Content-Type: application/json' -d {payload:q} {url:q}")
