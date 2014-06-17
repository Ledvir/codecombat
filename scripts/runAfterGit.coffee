return console.log '-------------------------------------------------
Commandline utility written in Coffeescript to run all updates, download latest database and install it after you git pushed.
Params:
\t--skipupdates skips npm and bower update
\t--dldb: download the latest database (Over 300 mb!)
\t--resetdb: to reset the database and load dump from tmp. Will need a downloaded database or --dbdownload specified
\t--mongopath <.path/to/mongo>: to specify mongodb folder if not set in PATH.
\t--help: Yo fund this one already.

May need an initial npm install upfront if newly checked out.
' if '--help' in path

dbDump = 'http://23.21.59.137/dump.tar.gz' # Don't change this unless you know what you're doing
dbLocalPath = '../temp'

fs = require 'fs'
tar = require 'tar'
spawn = require('child_process').spawn
http = require 'http'
fs = require 'fs'
zlib = require 'zlib'
Deferred = require 'JQDeferred'

#TODO: Could kill current coco server here.

mongopath = ''
useNext = false
for path in process.argv
  if useNext
    mongopath = path
    break
  useNext = path == '--mongopath'
mongopath += '/bin/' if mongopath.length
mongopath += 'mongodb' # mongodb is in path.

run = (proc, args) ->
  deferred = Deferred()
  spawned = spawn proc, args
  spawned.stdout.on "data", (data) -> process.stdout.write data
  spawned.stderr.on "data", (data) -> process.stderr.write data
  spawned.on "exit", (code) ->
    console.log proc + " exited with code " + code
    unless code is null
      deferred.reject code
    else
      deferred.resolve()
  deferred.promise()

removeDir = (path) ->
  if fs.existsSync(path)
    fs.readdirSync(path).forEach (file) ->
      current = path + "/" + file
      if fs.lstatSync(current).isDirectory() # recurse
        removeDir current
      else # delete file
        fs.unlinkSync current
    fs.rmdirSync path

resetDB = ->
  deferred = Deferred()
  console.log "Dropping Database"
  mongodrop = run "mongo", ["coco", "--eval", "db.dropDatabase()"]
  mongodrop.fail -> console.error "Error occurred"
  mongodrop.always ->
    console.log "Restoring from dump."
    mongorestore = run "mongorestore", [dbLocalPath]
    mongorestore.always = deferred.resolve
  deferred.promise()

downloadDB = ->
  deferred = Deferred()
  #mongoose = require 'mongoose'
  # TODO: What if mongo is not running?
  console.log "Downloading Database dump. It's big. This may take a while..."
  request = http.get dbDump, (response)->
    unzip = response.pipe  npm = if process.platform is "win32" then "npm.cmd" else "npm"
  npminstall = run npm, ['update']
  npminstall.done ->
    bowerinstall = run 'bower', ['update'](zlib.createGunzip()).pipe(tar.Extract(path: dbLocalPath))
    # Log download
    currentChunk = 0
    cur = 0
    len = parseInt(response.headers['content-length'], 10)
    total = len / 1048576 #1048576 - bytes in  1Megabyte
    response.on 'data', (chunk) ->
      cur += chunk.length
      console.log 'DB dump download received chunk ' + currentChunk++ + ", "  + (100.0 * cur / len).toFixed(2) + "% finished of " + total.toFixed(0) + " mb"
    unzip.on('data', -> console.log "Unpacking zip...")
    unzip.on('error', (err) -> console.log "An error occurred while downloading DB Dump: " + err)
    unzip.on 'end', ->
      console.log "Finished downloading."
      deferred.resolve()
    deferred.promise()

installUpdates = ->
  deferred = Deferred()
  npm = if process.platform is "win32" then "npm.cmd" else "npm"
  npminstall = run npm, ['update']
  npminstall.done ->
    bowerinstall = run 'bower', ['update']
    deferred.resolve()
  deferred.promise()

cleanUpTmp = ->
  removeDir dbLocalPath

unless '--skipupdates' in process.argv
  installUpdates()

if '--resetdb' in process.argv
  if '--skipdownload' in process.argv
    resetDB().done ->
      cleanUpTmp() if '--cleanup' in process.argv
  else
    downloadDB().always ->
        resetDB().done ->
          cleanUpTmp() if '--cleanup' in process.argv

# TODO: Could advice to start SCOCODE.bat et al. here

