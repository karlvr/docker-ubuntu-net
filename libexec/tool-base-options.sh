#!/bin/bash

while getopts ":dsc" opt; do
  case $opt in
    d)
      DEV=1
      ;;
    s)
      STAGING=1
      ;;
    c)
      CONTINUE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

shift $((OPTIND-1))
