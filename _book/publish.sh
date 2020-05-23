#!/bin/bash
gitbook build .
git subtree push --prefix=_book origin gh-pages
