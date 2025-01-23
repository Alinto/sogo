#!/bin/bash


bold=$(tput bold)
normal=$(tput sgr0)
green=$(tput setaf 2)
white=$(tput setaf 7)
magenta=$(tput setaf 5)
cyan=$(tput setaf 6)
underline=$(tput smul)
no_underline=$(tput rmul)

cd /src/SOGo

echo "${white}                                                                                          "
echo "${white}                                                                                          "
echo "${white}                                                                                          "
echo "${white}                                                                       ${green}▒▒▒▒${white}               "
echo "${white}                                                                    ${green}▒▒▒${white}    ${green}▒▒▒▒${white}           "
echo "${white}                                                                  ${green}▒▒▒${white}   ${green}▒▒▒${white}   ${green}▒▒${white}          "
echo "${white}                                                                 ${green}▒▒▒${white}  ${green}▒▒${white}   ${green}▒▒${white}  ${green}▒▒${white}         "
echo "${white}           ${green}▒▒▒▒▒▒▒▒▒▒${white}       ${green}▒▒▒▒▒▒▒▒▒▒▒${white}         ${green}▒▒▒▒▒▒▒▒▒▒▒▒${white}     ${green}▒▒${white}  ${green}▒▒${white}    ${green}▒▒${white}  ${green}▒▒${white}         "
echo "${white}          ${green}▒▒${white}       ${green}▒▒${white}     ${green}▒▒▒${white}         ${green}▒▒▒${white}      ${green}▒▒▒${white}         ${green}▒▒▒${white}    ${green}▒▒${white}  ${green}▒▒▒▒▒▒${white}  ${green}▒▒▒${white}         "
echo "${white}          ${green}▒▒▒${white}            ${green}▒▒▒${white}           ${green}▒▒▒${white}    ${green}▒▒${white}            ${green}▒▒▒${white}    ${green}▒▒${white}        ${green}▒▒▒${white}          "
echo "${white}           ${green}▒▒▒▒▒▒▒${white}       ${green}▒▒▒${white}            ${green}▒▒${white}   ${green}▒▒▒${white}            ${green}▒▒▒${white}      ${green}▒▒▒▒▒▒▒▒▒${white}            "
echo "${white}                 ${green}▒▒▒▒${white}    ${green}▒▒▒${white}            ${green}▒▒${white}    ${green}▒▒${white}            ${green}▒▒▒${white}                           "
echo "${white}                   ${green}▒▒▒${white}    ${green}▒▒${white}           ${green}▒▒▒${white}    ${green}▒▒▒${white}           ${green}▒▒${white}                            "
echo "${white}         ${green}▒▒▒${white}       ${green}▒▒▒${white}     ${green}▒▒▒${white}        ${green}▒▒▒${white}      ${green}▒▒▒${white}        ${green}▒▒▒${white}                             "
echo "${white}           ${green}▒▒▒▒▒▒▒▒▒${white}         ${green}▒▒▒▒▒▒▒▒▒▒${white}          ${green}▒▒▒▒▒▒▒▒▒▒${white}                               "
echo "${white}                                                 ${green}▒▒▒${white}                                      "
echo "${white}                                                 ${green}▒▒${white}                                       "
echo "${white}                                               ${green}▒▒▒▒▒▒▒▒▒▒▒▒▒${white}                              "
echo "${white}                                              ${green}▒▒▒${white}          ${green}▒▒▒${white}                            "
echo "${white}                                              ${green}▒▒${white}            ${green}▒▒▒${white}                           "
echo "${white}                                              ${green}▒▒${white}            ${green}▒▒${white}                            "
echo "${white}                                               ${green}▒▒▒▒${white}       ${green}▒▒▒▒${white}                            "
echo "${white}                                                 ${green}▒▒▒▒▒▒▒▒▒▒${white}                               "
echo "${white}                                                                                          "
echo "${white}                                                                      ${bold}${green}DEVELOPER${normal}           "
echo "${white}                                                                                          "
echo "${bold}${magenta}Access : https://127.0.0.1/SOGo/${normal}"
echo "${bold}${cyan}Use ${underline}devenv${no_underline} command to start${normal}"
echo ""

HAS_OLD_SOGO_INSTANCE=$(find /usr/local/lib/sogo/ -type f -name libSOGoUI.so.* | wc -l)
if [ "$HAS_OLD_SOGO_INSTANCE" -gt 1 ]; then
    echo "${bold}${red}/!\ You have an instable dev environment (two sogo libraries versions). This can be caused by a disynchronized SOGo code source (docker and local environment) This can be fixed by updating your local git repositories, delete and rebuild docker compose. You can also run devenv -ba.${normal}"
fi


/etc/init.d/sogod restart
# Run for ever
tail -f /dev/null
