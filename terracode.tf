provider "aws" {
	region = "ap-south-1"
	profile = "Sara"
}

//Creating Key
resource "tls_private_key" "tls_key" {
  algorithm = "RSA"
}


//Generating Key-Value Pair
resource "aws_key_pair" "generated_key" {
  key_name   = "rg-env-key"
  public_key = "${tls_private_key.tls_key.public_key_openssh}"


  depends_on = [
    tls_private_key.tls_key
  ]
}


//Saving Private Key PEM File
resource "local_file" "key-file" {
  content  = "${tls_private_key.tls_key.private_key_pem}"
  filename = "rg-env-key.pem"


  depends_on = [
    tls_private_key.tls_key
  ]
}

resource "aws_security_group" "mysg" {
	name = "httpfirewall"
	description = "Allow ssh-22 and http-80 protocols"
	ingress {
	   description = "SSH"
	   from_port = 22
	   to_port = 22
	   protocol = "tcp"
	   cidr_blocks = ["0.0.0.0/0"]
	}
	ingress {
	   description = "HTTP"
	   from_port = 80
	   to_port = 80
	   protocol = "tcp"
	   cidr_blocks = ["0.0.0.0/0"]
	}
	egress {
	   from_port = 0
	   to_port = 0
	   protocol = "-1"
	   cidr_blocks = ["0.0.0.0/0"]
	}
	tags = {
	   Name = "httpfirewall"
	}
}


resource "aws_instance" "myins" {
	ami            = "ami-0447a12f28fddb066"
        instance_type  = "t2.micro"
	key_name       = aws_key_pair.generated_key.key_name
	security_groups = ["httpfirewall"]

	tags = {
	   Name = "terraformos1"
	}
}

output "terraos_ip" {
	value = aws_instance.myins.public_ip
}

resource "null_resource" "remote1" {

    depends_on = [aws_instance.myins]
	 	provisioner "remote-exec" {
		   connection {
			     type = "ssh"
			     user = "ec2-user"
			     private_key = tls_private_key.tls_key.private_key_pem//file("C:/Users/KIIT/Desktop/Terraform/cloudtask/rg-env-key.pem")
			     host = aws_instance.myins.public_ip
	 }
	 	   inline = [
	 		"sudo yum install httpd git -y",
	 		"sudo systemctl restart httpd",
	 		"sudo systemctl enable httpd",
	 		]
	 	}
}

resource "null_resource" "nullres1" {
	provisioner "local-exec" {
	   command = "echo ${aws_instance.myins.public_ip} > ospubip.txt"
	}
}

resource "aws_ebs_volume" "newvol" {
	availability_zone = aws_instance.myins.availability_zone
	size = 1
	tags = {
	   Name = "newvol"
	}
}

resource "aws_volume_attachment" "attachvol" {
	device_name = "/dev/sdh"
	volume_id = aws_ebs_volume.newvol.id
	instance_id = aws_instance.myins.id
	depends_on = [
	   aws_ebs_volume.newvol,
           aws_instance.myins
	]
}

resource "null_resource" "nullres2"  {
depends_on = [
	aws_volume_attachment.attachvol,
	]


provisioner "remote-exec" {
  connection {
	    agent = false
	    type = "ssh"
	    user = "ec2-user"
	    private_key = tls_private_key.tls_key.private_key_pem//file("C:/Users/KIIT/Desktop/Terraform/cloudtask/rg-env-key.pem")
	    host = aws_instance.myins.public_ip
	}
	inline = [
	"sudo mkfs.ext4  /dev/xvdh",
	"sudo mount  /dev/xvdh  /var/www/html",
	"sudo rm -rf /var/www/html/*",
	"sudo git clone https://github.com/SaranyaChattopadhyay/cloud_createins.git /var/www/html",
        ]
    }
}

resource "aws_s3_bucket" "store" {
	bucket = "storebuck"
	acl = "public-read"
	tags = {
	   Name = "bucket"
	}
	versioning {
	   enabled = true
	}
}

resource "aws_s3_bucket_public_access_block" "s3Bucketblock" {
	bucket = "${aws_s3_bucket.store.id}"
	block_public_acls   = true
        block_public_policy = true
}

resource "aws_s3_bucket_object" "myobj1" {
	bucket = "storebuck"
	key    = "awsterra.jpg"
	source = "C:/Users/KIIT/Downloads/awsterra.jpg"
	acl = "public-read"
	content_type = "image or jpg"
	depends_on = [
           aws_s3_bucket.store
        ]
}

resource "aws_cloudfront_distribution" "s3Cloudfront1" {
	origin {
           domain_name = "store.s3.amazonaws.com"
           origin_id   = "S3-store"
           custom_origin_config {
        	http_port = 80
		https_port = 80
		origin_protocol_policy = "match-viewer"
		origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
	enabled = true
        default_cache_behavior {
           allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
           cached_methods = ["GET", "HEAD"]
           target_origin_id = "S3-store"
           forwarded_values {
		query_string = false
		cookies {
                   forward = "none"
              }
           }
	   viewer_protocol_policy = "allow-all"
           min_ttl = 0
           default_ttl = 3600
           max_ttl = 86400
        }

	restrictions {
           geo_restriction {
		restriction_type = "none"
           }
        }
        viewer_certificate {
           cloudfront_default_certificate = true
    }
    depends_on = [
        aws_s3_bucket_object.myobj1
    ]
}


resource "null_resource" "nullres3" {
	depends_on = [
	   null_resource.nullres2,
	]
	provisioner "local-exec" {
	   command = "start chrome  ${aws_instance.myins.public_ip}"
	}
}
