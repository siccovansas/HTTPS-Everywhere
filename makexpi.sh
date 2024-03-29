#!/bin/sh
APP_NAME=https-everywhere

# builds a .xpi from the git repository, placing the .xpi in the root
# of the repository.
#
# invoke with no arguments to build from the current src directory.
#
#  ./makexpi.sh
#
# OR, invoke with a tag name to build a specific branch or tag.
#
# e.g.:
#
#  ./makexpi.sh 0.2.3.development.2

cd "`dirname $0`"

# If the command line argument is a tag name, check that out and build it
if [ -n "$1" ]; then
	BRANCH=`git branch | head -n 1 | cut -d \  -f 2-`
	SUBDIR=checkout
	[ -d $SUBDIR ] || mkdir $SUBDIR
	cp -r -f -a .git $SUBDIR
	cd $SUBDIR
	git reset --hard "$1"
fi

if [ -x trivial-validate.py ]; then
	VALIDATE="python trivial-validate.py --ignoredups google --ignoredups facebook"
else
	VALIDATE="python trivial-validate"
fi
if $VALIDATE src/chrome/content/rules >&2
then
  echo Validation of included rulesets completed. >&2
  echo >&2
else
  echo ERROR: Validation of rulesets failed. >&2
  exit 1
fi

if [ -f relaxng.xml -a -x "$(which xmllint)" ] >&2
then
  if xmllint --noout --relaxng relaxng.xml src/chrome/content/rules/*.xml
  then
    echo Validation of rulesets with RELAX NG grammar completed. >&2
  else
    echo ERROR: Validation of rulesets with RELAX NG grammar failed. >&2
    exit 1
  fi
else
  echo Validation of rulesets with RELAX NG grammar was SKIPPED. >&2
fi 2>&1 | grep -v validates

if [ -x ./compare-locales.sh ] >&2
then
  if ./compare-locales.sh >&2
  then
    echo Validation of included locales completed. >&2
  else
    echo ERROR: Validation of locales failed. >&2
    exit 1
  fi
fi

# The name/version of the XPI we're building comes from src/install.rdf
XPI_NAME="pkg/$APP_NAME-`grep em:version src/install.rdf | sed -e 's/[<>]/	/g' | cut -f3`"
if [ "$1" ]; then
	XPI_NAME="$XPI_NAME.xpi"
else
	XPI_NAME="$XPI_NAME~pre.xpi"
fi

[ -d pkg ] || mkdir pkg

# Used for figuring out which branch to pull from when viewing source for rules
GIT_OBJECT_FILE=".git/refs/heads/master"
GIT_COMMIT_ID="HEAD"
if [ -e "$GIT_OBJECT_FILE" ]; then
	GIT_COMMIT_ID=$(cat "$GIT_OBJECT_FILE")
fi


. merge-rulesets.sh
cd src

# Build the XPI!
rm -f "../$XPI_NAME"
zip -q -X -9r "../$XPI_NAME" . "-x@../.build_exclusions"

ret="$?"
if [ "$ret" != 0 ]; then
    rm -f "../$XPI_NAME"
    exit "$?"
else
  echo >&2 "Total included rules: `find chrome/content/rules -name "*.xml" | wc -l`"
  echo >&2 "Rules disabled by default: `find chrome/content/rules -name "*.xml" | xargs grep -F default_off | wc -l`"
  echo >&2 "Created $XPI_NAME"
  if [ -n "$BRANCH" ]; then
    cd ../..
    cp $SUBDIR/$XPI_NAME pkg
    rm -rf $SUBDIR
  fi
fi
