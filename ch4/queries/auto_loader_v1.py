from pyspark.sql import functions as F

source_path      = "/Volumes/omnifin/landing/fintech_events/kafka_transaction/"
schema_location  = "/Volumes/omnifin/landing/_schemas/fintech_events/kafka_transaction/"
checkpoint_location = "/Volumes/omnifin/landing/_checkpoints/kafka_transaction/"

(
		spark.readStream
		.format("cloudFiles")
		.option("cloudFiles.format", "json")
		.option("cloudFiles.schemaLocation", schema_location)
		.option("cloudFiles.inferColumnTypes", "true")
		.load(source_path)
		.withColumn("_landing_ts", F.current_timestamp())
		.withColumn("_source_file", F.col("_metadata.file_path"))
		.writeStream
		.option("checkpointLocation", checkpoint_location)
		.option("mergeSchema", "true")
		.trigger(availableNow=True)
		.toTable("omnifin.landing.kafka_transaction")
)