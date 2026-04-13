Cram CLI tests for scripts/detect_changes.sh
=============================================
These tests verify the CLI behaviour of detect_changes.sh.
$REPO_ROOT must be set to the repository root before running cram.
All commands share one shell session; git commits accumulate sequentially.

Shared setup: init a bare repo and define helpers.

  $ git init -q
  $ git config user.email "test@example.com"
  $ git config user.name "Test"
  $ git commit -q --allow-empty -m "initial"
  $ GH_OUT="$CRAMTMP/github_output"
  $ run_detect() { rm -f "$GH_OUT"; GITHUB_OUTPUT="$GH_OUT" bash "$REPO_ROOT/scripts/detect_changes.sh" 2>&1; }
  $ out_var() { grep "^${1}=" "$GH_OUT" 2>/dev/null | sed "s/^${1}=//"; }

No YAML changed, all HTML present → courses_to_generate is blank
-----------------------------------------------------------------

  $ echo "title: A" > coursea.yml && touch coursea.html
  $ git add -A && git commit -q -m "add course A"
  $ echo "readme" > README.md
  $ git add -A && git commit -q -m "add readme"
  $ run_detect > /dev/null
  $ out_var courses_to_generate
  \s* (re)

YAML changed → course appears in courses_to_generate
------------------------------------------------------

  $ echo "title: A v2" > coursea.yml
  $ git add -A && git commit -q -m "update coursea"
  $ run_detect | grep "needs regeneration"
  Course 'coursea' needs regeneration:
  $ out_var courses_to_generate | grep coursea
  * coursea* (glob)

HTML file missing → course appears in both outputs
--------------------------------------------------

  $ echo "title: B" > courseb.yml
  $ git add -A && git commit -q -m "add courseb yaml, no html"
  $ echo "note" > note.txt && git add -A && git commit -q -m "unrelated"
  $ run_detect | grep "courseb"
  Course 'courseb' needs regeneration:
  $ out_var courses_to_generate | grep courseb
  * courseb* (glob)
  $ out_var missing_html | grep courseb
  * courseb* (glob)

.github/ YAML files not treated as courses
------------------------------------------

  $ touch courseb.html
  $ mkdir -p .github/workflows
  $ echo "on: push" > .github/workflows/ci.yml
  $ git add -A && git commit -q -m "add workflow"
  $ echo "placeholder" > update.txt && git add -A && git commit -q -m "unrelated"
  $ run_detect > /dev/null
  $ out_var courses_to_generate | grep "ci\|\.github" || echo "no workflow courses"
  no workflow courses

Multiple courses – only changed course regenerated
--------------------------------------------------

  $ echo "title: D" > coursed.yml && touch coursed.html
  $ echo "title: E" > coursee.yml && touch coursee.html
  $ git add -A && git commit -q -m "add D and E"
  $ echo "title: D v2" > coursed.yml
  $ git add -A && git commit -q -m "update D"
  $ run_detect > /dev/null
  $ out_var courses_to_generate | grep coursed
  * coursed* (glob)
  $ out_var courses_to_generate | grep coursee || echo "coursee absent"
  coursee absent
