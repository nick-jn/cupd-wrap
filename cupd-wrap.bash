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
F_NEWS="normal"  # (normal, only, nil)
F_SYU="prompt"   # (prompt, noprompt, nil)
F_PACFILES="nil" # (nil, find, locate)

# for when a "--help, -help, help" arguments are passed
print_help() {
    printf "Usage: "
    printf "cupd-wrap [ARG]=[SINGLE SUB-ARG]\n\n"
    printf "ARGS      SUB-ARGS (first is default)\n"
    printf "=====================================\n"
    printf "news      normal - news are displayed along with updates\n"
    printf "          only   - display news and quit\n"
    printf "          nil    - do not display news along with updates\n\n"
    printf "syu       prompt   - display a (y/N) prompt before launching \"sudo pacman -Syu\"\n"
    printf "          noprompt - launch \"sudo pacman -Syu\" without a (y/N) prompt\n"
    printf "          nil      - do not launch \"sudo pacman -Syu\"\n\n"
    printf "pacfiles  nil    - do not search for *.pacsave/*.pacnew files in /\n"
    printf "          find   - use find to search for *.pacsave/*.pacnew files in /\n"
    printf "          locate - use locate to search for *.pacsave/*.pacnew files in /\n\n"
    printf "Examples:\n"
    printf "cupd-wrap syu=noprompt pacfiles=locate\n"
    printf "cupd-wrap news=nil syu=nil\n"

    exit 0
}

# parser for the program's arguments
parse_main_args() {
    # this is a simple finite state machine-like parser, it's not very elegant,
    # but it was easy to implement, and it gets the job done
    local parser_state="get_top_arg"
    declare -i set_flag_news=0
    declare -i set_flag_syu=0
    declare -i set_flag_pacfiles=0
    declare -i count=0
    local args="$*"

    if [[ $args == "" ]]; then
        return 0
    fi

    news_arg() {
        if ((set_flag_news == 1)); then
            printf "Error, news argument already set\n"
            exit 1
        fi

        case $i in
            "only")   F_NEWS="only";;
            "nil")    F_NEWS="nil";;
            "normal") F_NEWS="normal";;
            *) printf "Invalid argument:\n%s\n" "$i" && exit 1
        esac
        parser_state="get_top_arg"
        set_flag_news=1
    }
    
    syu_arg() {
        if ((set_flag_syu == 1)); then
            printf "Error, syu argument already set\n"
            exit 1
        fi

        case $i in
            "noprompt") F_SYU="noprompt";;
            "nil")      F_SYU="nil";;
            "prompt")   F_SYU="prompt";;
            *) printf "Invalid argument:\n%s\n" "$i" && exit 1
        esac
        parser_state="get_top_arg"
        set_flag_syu=1
    }

    pacfiles_arg() {
        if ((set_flag_pacfiles == 1)); then
            printf "Error, pacfiles argument already set\n"
            exit 1
        fi

        case $i in
            "find")   F_PACFILES="find";;
            "locate") F_PACFILES="locate";;
            "nil")    F_PACFILES="nil";;
            *) printf "Invalid argument:\n%s\n" "$i" && exit 1
        esac
        parser_state="get_top_arg"
        set_flag_pacfiles=1
    }

    top_arg() {
        case $i in
            "news")     parser_state="news";;
            "syu")      parser_state="syu";;
            "pacfiles") parser_state="pacfiles";;
            "--help")   print_help;;
            "-help")    print_help;;
            "help")     print_help;;
            *) printf "Invalid argument:\n%s\n" "$i" && exit 1
        esac
    }

    IFS=" ="
    declare -i count=0
    for i in $args; do
        ((++count))
        case $parser_state in
            "get_top_arg") top_arg;;
            "news")        news_arg;;
            "syu")         syu_arg;;
            "pacfiles")    pacfiles_arg;;
        esac
    done
    unset IFS

    if ((count % 2 != 0)); then
        printf "Argument not set:\n%s\n" "$i" && exit 1
    fi
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

    printf "%d new packages found\n" "$pacnum"

    # extract the relevant info from pacman -Si
    local psi_out
    psi_out="$(echo "$package_names" | \
               xargs pacman -Si | \
               grep -E 'Repository|Download Size' | \
               awk -F ": " '{if (NR%2 == 0) printf "%s\n", $2; else printf "%s ", $2}')"

    # psi_out="$(echo "$package_names" | xargs pacman -Si)"
    # psi_out="$(echo "$psi_out" | grep -E 'Repository|Download Size' | \
              # awk -F ": " '{if (NR%2 == 0) printf "%s\n", $2; else printf "%s ", $2}')"

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
        case "$(echo "$i" | cut -d ' ' -f 1)" in
            "core")      core_out+="$i\n";;
            "extra")     extra_out+="$i\n";;
            "community") community_out+="$i\n";;
            *)           rest_out+="$i\n";;
        esac
    done
    unset IFS

    echo -e "$core_out" | head -c -1
    echo -e "$extra_out" | head -c -1
    echo -e "$community_out" | head -c -1
    echo -e "$rest_out" | head -c -1

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
        printf "\nLaunch sudo pacman -Syu? (y/N) "
        local ch
        read -r ch
        if [[ ! $ch == "y" ]] && [[ ! $ch == "Y" ]]; then
            printf "\nUpdate cancelled.\n"
            exit
        fi
        printf "\n"
    fi
    sudo pacman -Syu
}

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
    if [[ $F_NEWS == "only" ]]; then
        get_news && exit 0
    fi

    cupd_wrap && printf "\n"

    case $F_NEWS in
        "normal") get_news;;
        "nil")    ;;
    esac

    case $F_SYU in
        "prompt")   launch_syu "prompt";;
        "noprompt") launch_syu;;
        "nil")      ;;
    esac

    case $F_PACFILES in
        "find")   find_pacfiles "find" && printf "\n";;
        "locate") find_pacfiles "locate" && printf "\n";;
        "nil")    ;;
    esac

    exit 0
}

################################################################################

parse_main_args "$@"
check_prereq
main
