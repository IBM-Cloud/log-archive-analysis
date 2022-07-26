locals {
  resource_group = data.ibm_resource_group.all_rg.id
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
  bucket_name          = "${var.prefix}-${var.bucket_suffix}"
  resource_instance_id = ibm_resource_instance.cos.id
  region_location      = var.region
  storage_class        = "smart"
  force_delete         = true
}

resource "ibm_cos_bucket" "data_engine" {
  bucket_name          = "${var.prefix}-data-engine-${var.bucket_suffix}"
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

#--- iam for logging to write to COS bucket
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
    Endpoint   = ibm_cos_bucket.archive.s3_endpoint_private
    APIKey     = ibm_iam_service_api_key.write_bucket_archive.apikey
    InstanceId = ibm_resource_instance.cos.crn
  }
  sensitive = true
}


#--- iam for jupyter notebook to use data engine and data engine to access cos buckets

resource "ibm_iam_service_id" "jupyter_notebook" {
  name = "${var.prefix}-jupyter-notebook"
}

resource "ibm_iam_service_policy" "jupyter_notebook1" {
  iam_service_id = ibm_iam_service_id.jupyter_notebook.id
  roles          = ["Reader"]
  resources {
    service              = "cloud-object-storage"
    resource_instance_id = ibm_resource_instance.cos.guid
    resource_type        = "bucket"
    resource             = ibm_cos_bucket.archive.bucket_name
  }
}
resource "ibm_iam_service_policy" "jupyter_notebook2" {
  iam_service_id = ibm_iam_service_id.jupyter_notebook.id
  roles          = ["Writer"]
  resources {
    service              = "cloud-object-storage"
    resource_instance_id = ibm_resource_instance.cos.guid
    resource_type        = "bucket"
    resource             = ibm_cos_bucket.data_engine.bucket_name
  }
}
resource "ibm_iam_service_policy" "jupyter_notebook3" {
  iam_service_id = ibm_iam_service_id.jupyter_notebook.id
  roles          = ["Writer"]
  resources {
    service              = ibm_resource_instance.data_engine.service
    resource_instance_id = ibm_resource_instance.data_engine.guid
  }
}

resource "ibm_iam_service_api_key" "jupyter_notebook" {
  name           = var.prefix
  iam_service_id = ibm_iam_service_id.jupyter_notebook.iam_id
}

locals {
  jupyter_notebook_configuration = {
    apikey                      = ibm_iam_service_api_key.jupyter_notebook.apikey
    data_engine_crn             = ibm_resource_instance.data_engine.crn
    bucket_archive              = ibm_cos_bucket.archive.bucket_name
    bucket_archive_endpoint     = ibm_cos_bucket.archive.s3_endpoint_public
    bucket_data_engine          = ibm_cos_bucket.data_engine.bucket_name
    bucket_data_engine_endpoint = ibm_cos_bucket.data_engine.s3_endpoint_public
  }
}

output "jupyter_notebook_configuration_python" {
  value     = <<-EOT
  apikey='${local.jupyter_notebook_configuration.apikey}'
  instancecrn='${local.jupyter_notebook_configuration.data_engine_crn}'
  dataengineurl='cos://${local.jupyter_notebook_configuration.bucket_data_engine_endpoint}/${local.jupyter_notebook_configuration.bucket_data_engine}'
  logsurl='cos://${local.jupyter_notebook_configuration.bucket_archive_endpoint}/${local.jupyter_notebook_configuration.bucket_archive}'
  EOT
  sensitive = true
}
