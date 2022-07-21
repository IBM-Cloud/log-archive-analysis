locals {
  resource_group = data.ibm_resource_group.all_rg.id
  bucket_suffix  = "001" # all buckets must be globally unique
}

data "ibm_resource_group" "all_rg" {
  name = var.resource_group_name
}

#--- cos
resource "ibm_resource_instance" "cos" {
  name              = "${var.prefix}-cos"
  resource_group_id = local.resource_group
  service           = "cloud-object-storage"
  plan              = "standard"
  location          = "global"
}

resource "ibm_cos_bucket" "archive" {
  bucket_name          = "${var.prefix}-${local.bucket_suffix}"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  storage_class        = "smart"
  force_delete         = true
}

resource "ibm_cos_bucket" "data_engine" {
  bucket_name          = "${var.prefix}-data-engine-${local.bucket_suffix}"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  storage_class        = "smart"
  force_delete         = true
}

#--- data engine
resource "ibm_resource_instance" "data_engine" {
  name              = "${var.prefix}-de"
  resource_group_id = local.resource_group
  service           = "sql-query"
  plan              = "standard"
  location          = var.region
}


#--- watson studio data sience experience 
resource "ibm_resource_instance" "watson" {
  name              = "${var.prefix}-watson"
  resource_group_id = local.resource_group
  service           = "data-science-experience"
  plan              = "professional-v1"
  location          = var.region
}

#--- iam
resource "ibm_iam_service_id" "write_bucket_archive" {
  name = "${var.prefix}-write-bucket"
}

resource "ibm_iam_service_policy" "policy" {
  iam_service_id = ibm_iam_service_id.write_bucket_archive.id
  roles          = ["Writer"]
  resources {
    service              = "cloud-object-storage"
    resource_instance_id = ibm_resource_instance.cos.guid
    resource_type        = "bucket"
    resource             = ibm_cos_bucket.archive.bucket_name
  }

}

resource "ibm_iam_service_api_key" "write_bucket_archive" {
  name           = var.prefix
  iam_service_id = ibm_iam_service_id.write_bucket_archive.iam_id
}


output "logging_dashboard_settings_archiving" {
  value = {
    Bucket     = ibm_cos_bucket.archive.bucket_name
    Endpoint   = ibm_cos_bucket.archive.s3_endpoint_public
    APIKey     = ibm_iam_service_api_key.write_bucket_archive.apikey
    InstanceId = ibm_resource_instance.cos.crn
  }
  sensitive = true
}

/*
*/

