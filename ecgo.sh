#!/bin/bash
#
# Author: Novak Boškov <gnovak.boskov@gmail.com>
# Date: Dec, 2020.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
set -e

# defaults
encrypt_args=""
decrypt_args=""
output=""

print_help() {
    echo -e "Encrypts the directory and pushes it to Google Drive."
    echo -e "(or any other destination that Rclone can handle)\n"
    echo -e "PLEASE MAKE SURE THAT THE NAME OF THE DIRECTORY YOU ENCRYPT DOES NOT REVEAL UNWANTED INFORMATION.\n"
    echo -e "Uses GnuPG to encrypt the directory and Rclone to push the directory to Google Drive."
    echo -e "Both gpg and rclone need to be installed.\n"
    echo -e "Usage: ./ecgo.sh OPTIONS\n"
    echo -e "Set SECRET_REMOTE_PATH environment variable to specify the rclone path where you want to put your ecnrypted data.\n"
    echo -e "OPTIONS:"
    echo -e "\t-h Prints the help message."
    echo -e "\t-e Encrypts the directory and pushes it to Google Drive."
    echo -e "\t-d Decrypts the directory."
    echo -e "\t-o Output directory (makes sense with -d)."
    echo -e "\n Examples:"
    echo -e "\tSECRET_REMOTE_PATH=my_remote:/Encrypted ./ecgo.sh -e ~/Pictures"
    echo -e "\t./ecgo.sh -d my_remote:/Encrypted/Pictures.tar.gz.gpg -o ~/Desktop"
}

encrypt() {
    if [ -z "$SECRET_REMOTE_PATH" ]; then
        echo "SECRET_REMOTE_PATH is not specified, please do so."
        exit
    fi

    dir_path=$(cd $1; pwd)         # handle relative paths
    temp=$(mktemp -d)
    dir_name=$(basename $dir_path) # last dir in the path
    echo -e "===> Compressing $dir_path ..."
    tar -C $dir_path -czf $temp/$dir_name.tar.gz .
    echo -e "===> Created the compressed archive $temp/$dir_name.tar.gz"
    echo -e "\n===> Output from your GPG \
(it asks for the \"recipients\", which is yourself. Add yourself and press Enter on the next prompt):"
    gpg -e $temp/$dir_name.tar.gz

    # push to remote
    echo -e "===> Rclone pushes data to $SECRET_REMOTE_PATH/$dir_name.tar.gz.gpg ..."
    rclone -P copy $temp/$dir_name.tar.gz.gpg $SECRET_REMOTE_PATH
}

decrypt() {
    archive_path=$1
    temp=$(mktemp -d)
    base_name=$(basename $archive_path | cut -d. -f1)

    if [[ $archive_path == *":"* ]]; then # rsync path is in use if path contains semicolons
        echo "===> Downloading archive from $archive_path ..."
        download_path=$temp/$(basename $archive_path)
        rclone -P copy $archive_path $temp
        archive_path=$download_path
    fi

    # decryption
    echo -e "===> Output from your GPG (it asks for the decryption key):"
    gpg -d -o $temp/$base_name.tar.gz $archive_path

    if [ -z $output ]; then         # output is optional
        $output=$(pwd)
    else
        output="$(cd $output; pwd)" # get rid of trailing slashes if any
    fi

    # untaring
    echo -e "===> Untaring $output/$base_name ..."
    mkdir $output/$base_name
    tar -xvf $temp/$base_name.tar.gz -C $output/$base_name
}

# parse options
while getopts "he:d:o:" option; do
    case $option in
        e) encrypt_args=$OPTARG
           ;;
        d) decrypt_args=$OPTARG
           ;;
        o) output=$OPTARG
           ;;
        h | *) print_help
               exit
               ;;
    esac
done

# take actions
if ! [ -z "$encrypt_args" ]; then
    encrypt $encrypt_args
    exit
elif ! [ -z "$decrypt_args" ]; then
    decrypt $decrypt_args
    exit
elif ! [ -z "$output" ]; then
    print_help
    exit
fi
