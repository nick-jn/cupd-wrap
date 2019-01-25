#!/bin/bash

# This is a simple script that refines the output of checkupdates and
# grabs the latest news from the Arch RSS news feed. The idea is to
# have some extra info before commiting to grabbing a fresh copy
# of the package database via pacman -Sy.
#
# You can also pass it a news argument (i.e., "bash cupd-wrap.bash news")
# just to get the news.
#
# Prerequisites: checkupdates (included in pacman-contrib), bc, xmllint.


# TODO: rewrite most of it using safer and saner bash

readonly DEPS="checkupdates bc xmllint"

# checks the prerequisites, if failed, we exit
check_prereq() {
    OUT=""
    flag=0
    for i in $DEPS; do
        if [ "$(command -v "$i")" == "" ]; then
            OUT+="$i "
            flag=1
        fi
    done

    if [ $flag = 1 ]; then
        printf "Error, dependencies missing:\n"
        for i in $OUT; do
            printf "%s\n" "$i"
        done
        exit
    fi
}

# wrapper for the checkupdate
cupd_wrap() {
    printf "Fetching data, please wait...\n\n"

    CULIST=$(checkupdates)
    if [[ $CULIST = "" ]]; then
        echo "No new packages"
        exit
    fi

    # calculate the number of packages, extract
    # package names and then feed them to pacman -Si
    IFS=$'\n'
    PNAMES=""
    for i in $CULIST
    do
        pacnum=$((pacnum+1))
        PNAMES+=$(printf "%s" "$i" | awk '{print $1}')" "
    done
    unset IFS

    echo "$pacnum new packages found"

    # extract the relevant info from pacman -Si
    PSI="pacman -Si $PNAMES"
    PSI="$(eval "$PSI")"
    PSI=$(echo "$PSI" | grep -E 'Repository|Download Size' | \
          awk -F ": " '{if (NR%2 == 0) printf "%s\n", $2; else printf "%s ", $2}')

    # combine pacman -Si info with the output of checkupdates
    OUT=$(paste <(echo "$PSI") <(echo "$CULIST") | column -t | tr -s " ")

    # calculate total download size and refine the output further
    IFS=$'\n'
    totsize_mb="0"
    for i in $OUT
    do
        cursize_bib=$(echo "$i" | cut -d ' ' -f 2,3)

        # generate appropriate conversion multipliers
        if [ "$(echo "$cursize_bib" | awk '{print $2}')" = "KiB" ]; then
            mul=0.001024
        else # assumes MiB
            mul=1.048576
        fi

        cursize_mb=$(echo "scale=1;($(echo "$cursize_bib" | \
                     awk '{print $1}')*$mul)" | bc)
        totsize_mb=$(echo "scale=1;$totsize_mb+$cursize_mb" | bc)
    done
    unset IFS

    # final output
    printf "\n%s\n" "$(echo -e "$OUT" | cut -d ' ' --complement -f 2,3 | \
            sort -d | column -t )"
    printf "\nTotal download size: %.2f MB or %.2f MiB\n" \
           "$totsize_mb" "$(echo "$totsize_mb"*0.953674 | bc)"
}

# news fetcher
get_news() {
    NEWS="$(curl -s https://www.archlinux.org/feeds/news/ | \
    xmllint --xpath //item/title\ \|\ //item/pubDate /dev/stdin | \
    sed -n 's:.*>\(.*\)<.*:\1:p' | \
    sed -r "s:&gt;:>:" | \
    sed -r "s:&lt;:<:" | \
    sed 's/^[\t ]*//g' | \
    tr -s " ")"

    IFS=$'\n'
    declare -i count=0
    for i in $NEWS; do
        if ((count % 2 == 0)); then
            item="$i"
        else
            printf "%s | %s\n" "$(date --date="$i" +%F)" "$item"
        fi

        ((++count))
    done
    unset IFS
}

# internal for fancy_print
fancy_line() {
    len=$1
    while ((len > 0))
    do
        printf "="
        ((len--))
    done
    printf "\n"
}

# prints as follows:
# =============
# PASSED_STRING
# =============
fancy_print() {
    s=$1
    printf "\n"
    fancy_line "${#s}"
    printf "%s\n" "$1"
    fancy_line "${#s}"
}

# prompts to launch pacman -Syu
launch_syu() {
    printf "\nLaunch sudo pacman -Syu? (y/N) "
    read -r CONT
    if [ ! "$CONT" = "y" ] && [ ! "$CONT" = "Y" ]; then
    printf "\nUpdate cancelled.\n"
    exit
    fi
    printf "\n"
    sudo pacman -Syu
}

main() {
    cupd_wrap

    fancy_print "https://www.archlinux.org/news"
    get_news

    launch_syu

    fancy_print "Listing all the .pacnew and .pacsave files in /"
    ls -lt "$(find / -name '*.pacnew' -or -name '*.pacsave 2>/dev/null')"
}

################################################################################

check_prereq

if [ "$1" = "news" ]; then
    get_news
    exit
fi

main

# fancy_print "Launching Trizen AUR update"
# trizen -Sua
