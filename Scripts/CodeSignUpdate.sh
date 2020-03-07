#!/bin/bash

#  CodeSignUpdate.sh
#  SwiftPrivilegedHelperApplication
#
#  Created by Erik Berglund.
#  Copyright © 2018 Erik Berglund. All rights reserved.

set -e
set -x

###
### CUSTOM VARIABLES
###

bundleIdentifierApplication="massawippi.protonvpn.mac"
bundleIdentifierHelper="massawippi.protonvpn.ProtonVPNNetworkHelper"

###
### STATIC VARIABLES
###

infoPlist="${INFOPLIST_FILE}"

if [[ $( /usr/libexec/PlistBuddy -c "Print NSPrincipalClass" "${infoPlist}" 2>/dev/null ) == "NSApplication" ]]; then
    target="application"
else
    target="helper"
fi

oidAppleDeveloperIDCA="1.2.840.113635.100.6.2.6"
oidAppleDeveloperIDApplication="1.2.840.113635.100.6.1.13"
oidAppleMacAppStoreApplication="1.2.840.113635.100.6.1.9"
oidAppleWWDRIntermediate="1.2.840.113635.100.6.2.1"

###
### FUNCTIONS
###

function appleGeneric {
    printf "%s" "anchor apple generic"
}

function appleDeveloperID {
    printf "%s" "certificate leaf[field.${oidAppleMacAppStoreApplication}] /* exists */ or certificate 1[field.${oidAppleDeveloperIDCA}] /* exists */ and certificate leaf[field.${oidAppleDeveloperIDApplication}] /* exists */"
}

function appleMacDeveloper {
    printf "%s" "certificate 1[field.${oidAppleWWDRIntermediate}]"
}

function identifierApplication {
    printf "%s" "identifier \"${bundleIdentifierApplication}\""
}

function identifierHelper {
    printf "%s" "identifier \"${bundleIdentifierHelper}\""
}


function developerID {
    developmentTeamIdentifier="${DEVELOPMENT_TEAM}"


    printf "%s" "certificate leaf[subject.OU] = ${developmentTeamIdentifier}"
}

function macDeveloper {
    macDeveloperCN="${EXPANDED_CODE_SIGN_IDENTITY_NAME}"


    printf "%s" "certificate leaf[subject.CN] = \"${macDeveloperCN}\""
}

function updateSMPrivilegedExecutables {
    /usr/libexec/PlistBuddy -c 'Delete SMPrivilegedExecutables' "${infoPlist}" || true
    /usr/libexec/PlistBuddy -c 'Add SMPrivilegedExecutables dict' "${infoPlist}"
    /usr/libexec/PlistBuddy -c 'Add SMPrivilegedExecutables:'"${bundleIdentifierHelper}"' string '"$( sed -E 's/\"/\\\"/g' <<< ${1})"'' "${infoPlist}"
}

function updateSMAuthorizedClients {
    /usr/libexec/PlistBuddy -c 'Delete SMAuthorizedClients' "${infoPlist}" || true
    /usr/libexec/PlistBuddy -c 'Add SMAuthorizedClients array' "${infoPlist}"
    /usr/libexec/PlistBuddy -c 'Add SMAuthorizedClients: string '"$( sed -E 's/\"/\\\"/g' <<< ${1})"'' "${infoPlist}"
}

###
### MAIN SCRIPT
###

echo "Xcode Action: ${ACTION}"
case "${ACTION}" in
    "build")

        appString=$( identifierApplication )
        appString="${appString} and $( appleGeneric )"
        appString="${appString} and $( macDeveloper )"
        appString="${appString} and $( appleMacDeveloper )"
        appString="${appString} /* exists */"
echo "${appString}"
        helperString=$( identifierHelper )
        helperString="${helperString} and $( appleGeneric )"
        helperString="${helperString} and $( macDeveloper )"
        helperString="${helperString} and $( appleMacDeveloper )"
        helperString="${helperString} /* exists */"
    ;;
    "install")
        appString=$( appleGeneric )
        appString="${appString} and $( identifierApplication )"
        appString="${appString} and ($( appleDeveloperID )"
        appString="${appString} and $( developerID ))"

        helperString=$( appleGeneric )
        helperString="${helperString} and $( identifierHelper )"
        helperString="${helperString} and ($( appleDeveloperID )"
        helperString="${helperString} and $( developerID ))"
    ;;
    *)
        printf "%s\n" "Unknown Xcode Action: ${ACTION}"
        exit 1
    ;;
esac

echo "Xcode target: ${target}"

case "${target}" in
    "helper")
        updateSMAuthorizedClients "${appString}"
    ;;
    "application")
        updateSMPrivilegedExecutables "${helperString}"
    ;;
    *)
        printf "%s\n" "Unknown Target: ${target}"
        exit 1
    ;;
esac
