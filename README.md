# cupd-wrap
Wrapper for Arch Linux's checkupdate tool

This script refines the output of checkupdates and grabs
the latest news from the Arch RSS news feed. The idea is to
have some extra info before commiting to grabbing a fresh copy
of the package database via pacman -Sy.

Prerequisites: checkupdates (in pacman-contrib), xmllint (in libxml2).

    Usage: cupd-wrap [ARGS]
    =======================
    updates              execute the checkupdates wrapper module
    news                 fetch and display the latest Arch news
    syu       =prompt    display a (y/N) prompt before launching "sudo pacman -Syu"
              =noprompt  launch "sudo pacman -Syu" without a (y/N) prompt
    pacfiles  =find      use find to search for *.pacsave/*.pacnew files in /
              =locate    use locate to search for *.pacsave/*.pacnew files in /
    
    Examples:
    =========
    cupd-wrap updates news syu=noprompt pacfiles=locate
    cupd-wrap news

Use at your own risk.