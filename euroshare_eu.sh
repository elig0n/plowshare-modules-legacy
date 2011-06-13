#!/bin/bash
#
# euroshare.eu module
# Copyright (c) 2011 halfman <Pulpan3@gmail.com>
#
# This file is part of Plowshare.
#
# Plowshare is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Plowshare is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Plowshare.  If not, see <http://www.gnu.org/licenses/>.

MODULE_EUROSHARE_EU_REGEXP_URL="http://\(www\.\)\?euroshare\.eu/"

MODULE_EUROSHARE_EU_DOWNLOAD_OPTIONS="
AUTH_FREE,b:,auth-free:,USER:PASSWORD,Free-membership"
MODULE_EUROSHARE_EU_DOWNLOAD_RESUME=no
MODULE_EUROSHARE_EU_DOWNLOAD_FINAL_LINK_NEEDS_COOKIE=no

# Output a euroshare.eu file download URL
# $1: cookie file
# $2: euroshare.eu url
# stdout: real file download link
euroshare_eu_download() {
    eval "$(process_options euroshare_eu "$MODULE_EUROSHARE_EU_DOWNLOAD_OPTIONS" "$@")"

    COOKIEFILE="$1"
    URL="$2"
    BASEURL=$(basename_url "$URL")

    # html returned uses utf-8 charset
    PAGE=$(curl "$URL")
    if match "<h2>Súbor sa nenašiel</h2>" "$PAGE"; then
        log_error "File not found."
        return 254
    elif test "$CHECK_LINK"; then
        return 255
    fi

    if test "$AUTH_FREE"; then
        LOGIN_DATA='login=$USER&pass=$PASSWORD&submit=Prihlásiť sa'
        CHECK_LOGIN=$(post_login "$AUTH_FREE" "$COOKIEFILE" "$LOGIN_DATA" "$BASEURL")

        if ! match "/logout" "$CHECK_LOGIN"; then
            log_error "Login process failed. Bad username or password?"
            return 1
        fi
    fi

    # Arbitrary wait (local variable)
    NO_FREE_SLOT_IDLE=125

    while retry_limit_not_reached || return 3; do

        # html returned uses utf-8 charset
        PAGE=$(curl -b "$COOKIEFILE" "$URL")

        if match "<h2>Prebieha sťahovanie</h2>" "$PAGE"; then
            log_error "You are already downloading a file from this IP."
            return 255
        fi

        if match "<center>Všetky sloty pre Free užívateľov sú obsadené." "$PAGE"; then
            no_arbitrary_wait || return 253
            wait $NO_FREE_SLOT_IDLE seconds || return 2
            continue
        fi
        break
    done

    DL_URL=$(echo "$PAGE" | parse_attr '<a class="stiahnut"' 'href')
    if ! test "$DL_URL"; then
        log_error "Can't parse download URL, site updated?"
        return 255
    fi

    DL_URL=$(curl -I "$DL_URL")

    FILENAME=$(echo "$DL_URL" | grep_http_header_content_disposition)

    FILE_URL=$(echo "$DL_URL" | grep_http_header_location)
    if ! test "$FILE_URL"; then
        log_error "Location not found"
        return 255
    fi

    echo "$FILE_URL"
    test "$FILENAME" && echo "$FILENAME"

    return 0
}
