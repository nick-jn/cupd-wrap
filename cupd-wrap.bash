#!/bin/bash

# This is a simple script that refines the output of checkupdates and
# grabs the latest news from the Arch RSS news feed. The idea is to
# have some extra info before commiting to grabbing a fresh copy
# of the package database via pacman -Sy.
#
# You can also pass it a news argument (i.e., "bash cupd-wrap.bash news")
# just to get the news.
#
# Prerequisites: checkupdates (included in pacman-contrib), xmllint (in libxml2).

# prints as follows:
# =============
# PASSED_STRING
# =============
fancy_print() {
    fancy_line() {
        declare -i length="$1"
        while ((length > 0)); do
            printf "="
            ((--length))
        done

        printf "\n"
    }

    local str="$1"
    printf "\n"
    fancy_line "${#str}"
    printf "%s\n" "$str"
    fancy_line "${#str}"
}

# checks the prerequisites, if failed, we exit
check_prereq() {
    local out=""
    readonly local deps="checkupdates xmllint"
    declare -i flag=0

    for i in $deps; do
        if [[ $(command -v "$i") == "" ]]; then
            out+="$i "
            flag=1
        fi
    done

    if ((flag == 1)); then
        printf "Error, dependencies missing:\n"
        for i in $out; do
            printf "%s\n" "$i"
        done
        exit 1
    fi
}

# wrapper for checkupdate
cupd_wrap() {
    printf "Fetching data, please wait...\n\n"

    local cupd_out

    if [[ $1 == "test" ]]; then
        cupd_out="$(printf "vim\nbash\nemacs\nlinux\nkitty")"
    else
        cupd_out=$(checkupdates)
    fi

    if [[ $cupd_out = "" ]]; then
        echo "No new packages"
        exit
    fi

    # calculate the number of packages, extract
    # package names and then feed them to pacman -Si
    local package_names=""
    declare -i pacnum=0
    IFS=$'\n'
    for i in $cupd_out; do
        ((++pacnum))
        package_names+=$(printf "%s" "$i" | awk '{print $1}')" "
    done
    unset IFS

    echo "$pacnum new packages found"

    # extract the relevant info from pacman -Si
    local psi_out
    psi_out="$(echo "$package_names" | xargs pacman -Si)"
    psi_out="$(echo "$psi_out" | grep -E 'Repository|Download Size' | \
              awk -F ": " '{if (NR%2 == 0) printf "%s\n", $2; else printf "%s ", $2}')"

    # combine pacman -Si info with the output of checkupdates
    local comb_out
    comb_out="$(paste <(echo "$psi_out") <(echo "$cupd_out") | column -t | tr -s " ")"

    # calculate total download size
    local cursize
    local totsize
    IFS=$'\n'
    for i in $comb_out; do
        cursize=$(echo "$i" | cut -d ' ' -f 2,3)

        # generate appropriate conversion multipliers
        if [[ $(echo "$cursize" | awk '{print $2}') = "KiB" ]]; then
            cursize="$(echo "$cursize" | awk '{printf "%f", $1/1024}')"
        fi

        totsize="$(echo "$cursize $totsize" | awk '{printf "%f", $1+$2}')"
    done
    unset IFS

    # final output
    printf "\n%s\n" "$(echo -e "$comb_out" | cut -d ' ' --complement -f 2,3 | \
            sort -d | column -t )"
    printf "\nTotal download size: approx. %.2f MiB\n" "$totsize"
}

# news fetcher
get_news() {
    fancy_print "https://www.archlinux.org/news"
    local news
    news="$(curl -s https://www.archlinux.org/feeds/news/ | \
    xmllint --xpath //item/title\ \|\ //item/pubDate /dev/stdin | \
    sed -n 's:.*>\(.*\)<.*:\1:p' | \
    sed -r "s:&gt;:>:" | \
    sed -r "s:&lt;:<:" | \
    sed 's/^[\t ]*//g' | \
    tr -s " " | \
    head -n 10)" # multiply the desired amount of news items to be printed by 2

    IFS=$'\n'
    declare -i count=0
    for i in $news; do
        if ((count % 2 == 0)); then
            item="$i"
        else
            printf "%s | %s\n" "$(date --date="$i" +%F)" "$item"
        fi
        ((++count))
    done
    unset IFS
}

# prompts to launch pacman -Syu
launch_syu() {
    printf "\nLaunch sudo pacman -Syu? (y/N) "
    local ch
    read -r ch
    if [[ ! $ch == "y" ]] && [[ ! $ch == "Y" ]]; then
        printf "\nUpdate cancelled.\n"
        exit
    fi
    printf "\n"
    sudo pacman -Syu
}

find_pacfiles() {
    find_with_find() {
        find / \( -name '*.pacnew' -or -name '*.pacsave' \) -print0 2>/dev/null | xargs -0 ls -lt 
    }

    fancy_print "Listing all the .pacnew and .pacsave files in /"
    if [[ ! $(command -v "locate") == "" ]];then
        if ! updatedb; then
            printf "Locate found, but failed to update the database. Using find instead.\n\n"
            find_with_find
        else
            locate --existing --regex "\.pac(new|save)$" | xargs ls -lt
        fi
    else
        find_with_find
    fi
}

main() {
    check_prereq
    if [[ $1 == "news" ]]; then
        get_news
        exit 0
    fi

    cupd_wrap "$@"
    get_news
    launch_syu
    find_pacfiles

    if [[ ! $(command -v "trizen") == "" ]]; then
        fancy_print "Launching Trizen AUR update"
        trizen -Sua
    fi

    exit 0
}

################################################################################

main "$@"
