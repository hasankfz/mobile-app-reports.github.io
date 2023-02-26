data "aws_ssoadmin_instances" "roles_configuration" {}

resource "aws_ssoadmin_permission_set" "permission_set" {
  name         = var.permission_set
  description  = "Permission sets name"
  instance_arn = tolist(data.aws_ssoadmin_instances.roles_configuration.arns)[0]
}

resource "aws_ssoadmin_managed_policy_attachment" "policy_attachment" {
  for_each = toset(var.managed_policies)

  instance_arn       = tolist(data.aws_ssoadmin_instances.roles_configuration.arns)[0]
  managed_policy_arn = each.value
  permission_set_arn = aws_ssoadmin_permission_set.permission_set.arn
}

resource "aws_iam_policy" "customer_managed_policy" {
  for_each = var.customer_managed_policies == null ? toset([]) : toset(keys({ for key, policy in var.customer_managed_policies : key => policy }))

  name        = var.customer_managed_policies[each.value]["name"]
  description = var.customer_managed_policies[each.value]["description"]
  policy      = jsonencode(var.customer_managed_policies[each.value]["Policy"])

}

resource "aws_ssoadmin_customer_managed_policy_attachment" "customer_managed_policy_attachment" {
  for_each = var.customer_managed_policies == null ? toset([]) : toset(keys({ for key, policy in var.customer_managed_policies : key => policy }))

  instance_arn       = aws_ssoadmin_permission_set.permission_set.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.permission_set.arn
  customer_managed_policy_reference {
    name = aws_iam_policy.customer_managed_policy[each.value]["name"]
    path = "/"

  }
}

data "aws_identitystore_group" "group_attachment" {
  for_each = toset(var.user_group)

  identity_store_id = tolist(data.aws_ssoadmin_instances.roles_configuration.identity_store_ids)[0]

  filter {
    attribute_path  = "DisplayName"
    attribute_value = each.key
  }
}

resource "aws_ssoadmin_account_assignment" "account_assignment" {
  for_each = toset(keys({for key, value in local.account_and_group : key => value }))

  instance_arn       = tolist(data.aws_ssoadmin_instances.roles_configuration.arns)[0]
  permission_set_arn = aws_ssoadmin_permission_set.permission_set.arn

  principal_id = data.aws_identitystore_group.group_attachment[local.account_and_group[each.value]["user_group"]].group_id
  principal_type = "GROUP"

  target_id   = local.account_and_group[each.value]["account"]
  target_type = "AWS_ACCOUNT"
}

locals {
  account_and_group = flatten([
    for account in var.account : [
      for user_group in var.user_group: {
        account = account
        user_group = user_group
      }
  ]])
}
