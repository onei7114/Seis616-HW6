provider "aws" {
  region = "us-east-1"
}
#An S3 bucket where users can upload pictures.
resource "aws_s3_bucket" "image_upload_bucket" {
  bucket = "image-upload-bucket-3456789087" #

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT", "POST"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  tags = {
    Name        = "Image Upload Bucket"
    Environment = "Dev"
  }
}

resource "aws_s3_bucket_policy" "upload_policy" {
  bucket = aws_s3_bucket.image_upload_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowUploads"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:PutObject"
        ]
        Resource = "${aws_s3_bucket.image_upload_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "public-read"
          }
        }
      }
    ]
  })
}
# 2. An S3 bucket to store outputs from the functions
resource "aws_s3_bucket" "output_bucket" {
  bucket = "output-bucket-354576587"

  tags = {
    Name        = "Function Output Bucket"
    Environment = "Dev"
  }
}


#lambda function for buckets
resource "aws_iam_role" "lambda_exec_role" {
  name = "lambda_s3_exec_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda_s3_policy" {
  name = "lambda_s3_access"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ],
        Resource = [
          "${aws_s3_bucket.image_upload_bucket.arn}/*",
          "${aws_s3_bucket.output_bucket.arn}/*"
        ]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy_attach" {
  role       = aws_iam_role.lambda_exec_role.name
  policy_arn = aws_iam_policy.lambda_s3_policy.arn
}


#SNS Topic
resource "aws_sns_topic" "s3_event_topic" {
  name = "s3-event-topic"
}

#SQS Queues
resource "aws_sqs_queue" "thumbnail_queue" {
  name = "thumbnail-queue"
}

resource "aws_sqs_queue" "recognition_queue" {
  name = "recognition-queue"
}

resource "aws_sqs_queue" "metadata_queue" {
  name = "metadata-queue"
}

#SNS Subscriptions
resource "aws_sns_topic_subscription" "thumb_sub" {
  topic_arn = aws_sns_topic.s3_event_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.thumbnail_queue.arn
}

resource "aws_sns_topic_subscription" "recog_sub" {
  topic_arn = aws_sns_topic.s3_event_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.recognition_queue.arn
}

resource "aws_sns_topic_subscription" "meta_sub" {
  topic_arn = aws_sns_topic.s3_event_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.metadata_queue.arn
}


resource "aws_sqs_queue_policy" "thumb_policy" {
  queue_url = aws_sqs_queue.thumbnail_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSNS",
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.thumbnail_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.s3_event_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "recog_policy" {
  queue_url = aws_sqs_queue.recognition_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSNS",
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.recognition_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.s3_event_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_sqs_queue_policy" "meta_policy" {
  queue_url = aws_sqs_queue.metadata_queue.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowSNS",
        Effect    = "Allow",
        Principal = "*",
        Action    = "sqs:SendMessage",
        Resource  = aws_sqs_queue.metadata_queue.arn,
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.s3_event_topic.arn
          }
        }
      }
    ]
  })
}

#notification
resource "aws_s3_bucket_notification" "s3_to_sns" {
  bucket = aws_s3_bucket.image_upload_bucket.id

  topic {
    topic_arn = aws_sns_topic.s3_event_topic.arn
    events    = ["s3:ObjectCreated:*"]
  }
}
