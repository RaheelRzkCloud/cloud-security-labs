# Conditional Access policy lab
# Requires MFA for sign-ins that look risky. Designed following the CISO's
# brief in Season 1, Session 7 - not "MFA for everyone, always" (which trains
# people to blindly approve prompts), but a targeted, risk-based policy.
#
# Note: this could not be applied live against a trial tenant, since
# Conditional Access requires an Entra ID P1/P2 license, which a personal
# free-trial tenant couldn't self-provision. Written and reasoned through as
# code instead - this is genuinely how Conditional Access is often managed
# in real organisations anyway (as code, not manual portal clicks).
#
# DESIGN NOTE - a mistake worth documenting:
# My first draft combined location and device conditions inside a single
# policy. Conditions within one Conditional Access policy are combined with
# AND logic, not OR - meaning that policy would only have required MFA when
# a sign-in was BOTH outside the UK AND on a non-compliant device at the
# same time. That missed real risk cases: a UK-based sign-in on an unmanaged
# personal device, or an overseas sign-in on a fully compliant company
# laptop. The fix is two separate, independent policies below, each firing
# on its own risk signal.

terraform {
  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.0"
    }
  }
}

provider "azuread" {}

# Named location: defines what "UK" actually means to this policy.
# Defined once, as its own resource, so any future policy needing the same
# definition references it rather than redefining it - one place to update
# if the definition ever needs to change.
resource "azuread_named_location" "uk_only" {
  display_name = "United Kingdom"

  country {
    countries_and_regions = ["GB"]
  }
}

# Policy 1: require MFA for sign-ins from outside the UK,
# regardless of what device is being used.
resource "azuread_conditional_access_policy" "outside_uk_mfa" {
  display_name = "Require MFA for sign-ins outside the UK"
  state        = "enabledForReportingButNotEnforced" # report-only first - see README

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = [] # break-glass account ID would be excluded here - see README
    }

    locations {
      included_locations = ["All"]
      excluded_locations  = [azuread_named_location.uk_only.id]
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# Policy 2: require MFA for sign-ins from non-compliant/unmanaged devices,
# regardless of location.
resource "azuread_conditional_access_policy" "noncompliant_device_mfa" {
  display_name = "Require MFA for non-compliant devices"
  state        = "enabledForReportingButNotEnforced" # report-only first - see README

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
    }

    users {
      included_users = ["All"]
      excluded_users = [] # break-glass account ID would be excluded here - see README
    }

    devices {
      filter {
        mode = "include"
        rule = "device.trustType -ne \"AzureAD\"" # matches devices that are NOT Entra-joined/compliant
      }
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

