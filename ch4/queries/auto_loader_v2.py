from pyspark.sql import functions as F

source_path      = "/Volumes/omnifin/landing/fintech_events/kafka_transaction/"
checkpoint_location = "/Volumes/omnifin/landing/_checkpoints/kafka_transaction_v2/"

(
		spark.readStream
		.format("cloudFiles")
		.option("cloudFiles.format", "json")
		.option("singleVariantColumn", "payload")
		.load(source_path)
		.withColumn("_landing_ts", F.current_timestamp())
		.withColumn("_source_file", F.col("_metadata.file_path"))
		.writeStream
		.option("checkpointLocation", checkpoint_location)
		.trigger(availableNow=True)
		.toTable("omnifin.landing.kafka_transaction")
)