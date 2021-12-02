terraform {
  required_version = ">= 0.15"
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

//multiples all even numbers in an array by 10 and adds the results together
locals {
  numList = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
  result  = sum([for x in local.numList : x * 10 if x % 2 == 0])
}

variable "words" {
  type = object({
    nouns      = list(string)
    adjectives = list(string)
    verbs      = list(string)
    adverbs    = list(string)
    numbers    = list(number)
  })

  validation {
    condition     = length(var.words.nouns) > 10
    error_message = "Nouns should be greater than 20."
  }
}

locals {
  uppercase_words = { for k, v in var.words : k => [for s in v : upper(s)] }
  templates       = tolist(fileset(path.module, "template/*.txt"))
}

variable "num_files" {
  default = 10
  type    = number
}

resource "random_shuffle" "random_nouns" {
  count = var.num_files
  input = local.uppercase_words["nouns"]
}
resource "random_shuffle" "random_adjectives" {
  count = var.num_files
  input = local.uppercase_words["adjectives"]
}
resource "random_shuffle" "random_verbs" {
  count = var.num_files
  input = local.uppercase_words["verbs"]
}
resource "random_shuffle" "random_adverbs" {
  count = var.num_files
  input = local.uppercase_words["adverbs"]
}
resource "random_shuffle" "random_numbers" {
  count = var.num_files
  input = local.uppercase_words["numbers"]
}

resource "local_file" "mad_libs" {
  count    = var.num_files
  filename = "madlibs/madlibs-${count.index}.txt"
  content = templatefile(element(local.templates, count.index),
    {
      nouns      = random_shuffle.random_nouns[count.index].result
      adjectives = random_shuffle.random_adjectives[count.index].result
      verbs      = random_shuffle.random_verbs[count.index].result
      adverbs    = random_shuffle.random_adverbs[count.index].result
      numbers    = random_shuffle.random_numbers[count.index].result
  })
}

data "archive_file" "mad_libs" {
  depends_on  = [local_file.mad_libs]
  type        = "zip"
  source_dir  = "${path.module}/madlibs"
  output_path = "${path.cwd}/madlibs.zip"
}

#output "mad_libs" {
#  value = (templatefile("${path.module}/template/alice.txt",
#    {
#      nouns      = random_shuffle.random_nouns.result
#      adjectives = random_shuffle.random_adjectives.result
#      verbs      = random_shuffle.random_verbs.result
#      adverbs    = random_shuffle.random_adverbs.result
#      numbers    = random_shuffle.random_numbers.result
#  }))
#}