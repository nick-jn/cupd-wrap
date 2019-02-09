#!/usr/bin/env bash
# Wrapper for Arch Linux's checkupdate tool
#
# This script refines the output of checkupdates and grabs the latest news from
# the Arch RSS news feed. The idea is to have some extra info before commiting to
# grabbing a fresh copy of the package database via pacman -Sy.
#
# Prerequisites:
# ==============
# checkupdates (in pacman-contrib), xmllint (in libxml2).

# global flags for the program
F_UPDATES="nil"
F_NEWS="nil"
F_SYU="nil"
F_PACFILES="nil"

# prints help on how to use the program
print_help() {
    printf "Usage: cupd-wrap [ARGS]\n"
    printf "=======================\n"
    printf "updates              execute the checkupdates wrapper module\n"
    printf "news                 fetch and display the latest Arch news\n"
    printf "syu       =prompt    display a (y/N) prompt before launching \"sudo pacman -Syu\"\n"
    printf "          =noprompt  launch \"sudo pacman -Syu\" without a (y/N) prompt\n"
    printf "pacfiles  =find      use find to search for *.pacsave/*.pacnew files in /\n"
    printf "          =locate    use locate to search for *.pacsave/*.pacnew files in /\n\n"
    printf "Examples:\n"
    printf "=========\n"
    printf "cupd-wrap updates news syu=noprompt pacfiles=locate\n"
    printf "cupd-wrap news\n"

    exit 0
}

# parser for the program's arguments
parse_main_args() {
    declare -i setflag_syu=0
    declare -i setflag_pacfiles=0
    local args="$*"

    if [[ $args == "" ]]; then
        print_help && exit 1
    fi

    check_setflag() {
        if [[ $1 == 1 ]]; then
            printf "Error, argument for %s was already set\n" "$2" && exit 1
        fi
    }

    IFS=" "
    for i in $args; do
        case $i in
            "updates")         F_UPDATES="yes";;
            "news")            F_NEWS="yes";;

            "syu")             printf "Please provide a sub-argument for syu\n"
                               exit 1
                               ;;
            "syu=prompt")      check_setflag "$setflag_syu" "syu"
                               setflag_syu=1
                               F_SYU="prompt"
                               ;;
            "syu=noprompt")    check_setflag "$setflag_syu" "syu"
                               setflag_syu=1
                               F_SYU="noprompt"
                               ;;

            "pacfiles")        printf "Please provide a sub-argument for pacfiles\n"
                               exit 1
                               ;;
            "pacfiles=find")   check_setflag "$setflag_pacfiles" "pacfiles"
                               setflag_pacfiles=1
                               F_PACFILES="find"
                               ;;
            "pacfiles=locate") check_setflag "$setflag_pacfiles" "pacfiles"
                               setflag_pacfiles=1
                               F_PACFILES="locate"
                               ;;

            "--help")          print_help;;
            "-help")           print_help;;
            "help")            print_help;;
            *)                 printf "Invalid argument:\n%s\n" "$i" && exit 1;;
         esac
    done
    unset IFS
}

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
    cupd_out=$(checkupdates)
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

    printf "%d new packages found:\n" "$pacnum"

    # extract the relevant info from pacman -Si
    local psi_out
    psi_out="$(echo "$package_names" | \
               xargs pacman -Si | \
               grep -E 'Repository|Download Size' | \
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
        if [[ $(echo "$cursize" | awk '{print $2}') = "KiB" ]]; then
            cursize="$(echo "$cursize" | awk '{printf "%f", $1/1024}')"
        else
            cursize="$(echo "$cursize" | cut -d ' ' -f 1)"
        fi
        totsize="$(echo "$cursize $totsize" | awk '{printf "%f", $1+$2}')"
    done
    unset IFS

    # final output
    local final_out
    final_out=$(printf "\n%s\n" "$(echo -e "$comb_out" | \
                cut -d ' ' --complement -f 2,3 | \
                sort -d | column -t -o "  ")")

    # perhaps an extra argument for extracting the updates per repo?
    local core_out=""
    local extra_out=""
    local community_out=""
    local rest_out=""
    IFS=$'\n'
    for i in $final_out; do
        case "$(echo "$i" | awk '{print $1}')" in
            "core")      core_out+="$i\n";;
            "extra")     extra_out+="$i\n";;
            "community") community_out+="$i\n";;
            *)           rest_out+="$i\n";;
        esac
    done
    unset IFS

    final_out=$(echo -e "$core_out")
    final_out+=$(echo -e "\n$extra_out")
    final_out+=$(echo -e "\n$community_out")
    final_out+=$(echo -e "\n$rest_out")

    printf "%s\n" "$final_out"

    printf "\nTotal download size: approx. %.2f MiB\n" "$totsize"
}

# news fetcher
get_news() {
    fancy_print "https://www.archlinux.org/news"
    local news
    news="$(curl -s https://www.archlinux.org/feeds/news/ | \
    xmllint --xpath //item/title\ \|\ //item/pubDate /dev/stdin | \
    sed -n 's:.*>\(.*\)<.*:\1:p' | \
    sed -r 's:&gt;:>:' | \
    sed -r 's:&lt;:<:' | \
    sed 's/^[\t ]*//g' | \
    tr -s ' ' | \
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
    if [[ $1 == "prompt" ]]; then
        printf "Launch sudo pacman -Syu? (y/N) "
        local ch
        read -r ch
        if [[ ! $ch == "y" ]] && [[ ! $ch == "Y" ]]; then
            printf "\nUpdate cancelled.\n" && exit 1
        fi
        sudo pacman -Syu
    elif [[ $1 == "noprompt" ]]; then
        sudo pacman -Syu
    fi
}

# performs a search for .pacnew and .pacsave files in /
find_pacfiles() {
    fancy_print "Listing all the .pacnew and .pacsave files in /"
    if [[ $1 == "find" ]]; then
        find / \( -name '*.pacnew' -or -name '*.pacsave' \) -print0 2>/dev/null | \
        xargs -0 ls -lt 
    elif [[ $1 == "locate" ]]; then
        updatedb
        locate --existing --regex "\.pac(new|save)$" | \
        xargs ls -lt 
    fi
}

main() {
    local run_flag=0 # used for printing newlines between commands

    newl() {
        if [[ $run_flag == 1 ]]; then
            printf "\n"
            run_flag=0
        fi
    }

    case $F_UPDATES in
        "yes") cupd_wrap && run_flag=1;;
        "nil") ;;
    esac

    case $F_NEWS in
        "yes") newl && get_news && run_flag=1;;
        "nil") ;;
    esac

    case $F_SYU in
        "prompt")   newl && launch_syu "prompt"   && run_flag=1;;
        "noprompt") newl && launch_syu "noprompt" && run_flag=1;;
    esac

    case $F_PACFILES in
        "find")   newl && find_pacfiles "find";;
        "locate") newl && find_pacfiles "locate";;
    esac

    exit 0
}

################################################################################

parse_main_args "$@"
check_prereq
main
