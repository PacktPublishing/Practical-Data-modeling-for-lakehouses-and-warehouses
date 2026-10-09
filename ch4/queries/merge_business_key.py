from delta.tables import DeltaTable
from pyspark.sql import Window, functions as F

def merge_new_keys(batch_df, batch_id):
    # The same key can arrive from several sources in one micro-batch
    first_seen = Window.partitionBy("customer_hk").orderBy("load_dts", "record_source")
    new_keys = (batch_df.withColumn("rn", F.row_number().over(first_seen))
                        .filter("rn = 1").drop("rn"))
    (DeltaTable.forName(spark, "omnifin.raw_vault.hub_customer").alias("t")
        .merge(new_keys.alias("s"), "t.customer_hk = s.customer_hk")
        .whenNotMatchedInsertAll()
        .execute())

(spark.readStream.table("omnifin.raw_vault.stg_hub_customer_keys")
    .writeStream
    .foreachBatch(merge_new_keys)
    .option("checkpointLocation",
            "/Volumes/omnifin_prod/landing/_checkpoints/hub_customer_loader/")
    .trigger(availableNow=True)
    .start())