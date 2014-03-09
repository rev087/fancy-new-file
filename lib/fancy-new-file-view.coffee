{$$, View, EditorView} = require 'atom'
fs = require 'fs'
path = require 'path'

module.exports =
class FancyNewFileView extends View
  fancyNewFileView: null

  @activate: (state) ->
    @fancyNewFileView = new FancyNewFileView(state.fancyNewFileViewState)

  @deactivate: ->
    @fancyNewFileView.detach()

  @content: (params)->
    @div class: 'fancy-new-file overlay from-top', =>
      @p 'New File'
      @subview 'miniEditor', new EditorView({mini:true})
      @ul class: 'list-group', outlet: 'directoryList'

  initialize: (serializeState) ->
    atom.workspaceView.command "fancy-new-file:toggle", => @toggle()
    @miniEditor.setPlaceholderText('path/to/file.txt');

    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()

    consumeKeypress = (ev) => ev.preventDefault(); ev.stopPropagation()

    # Populate the directory listing live
    @miniEditor.getEditor().getBuffer().on 'changed', (ev) =>
      @getDirs (files) ->
        @renderDirList files

    # Consume the keydown event from holding down the Tab key
    @miniEditor.on 'keydown', (ev) => if ev.keyCode is 9 then consumeKeypress ev

    # Handle the Tab completion
    @miniEditor.on 'keyup', (ev) =>
      if ev.keyCode is 9
        consumeKeypress ev
        @autocomplete @miniEditor.getEditor().getText()

  # Returns the list of directories matching the current input (path and autocomplete fragment)
  getDirs: (callback) ->
    input = @miniEditor.getEditor().getText()
    inputPath = path.join atom.project.getPath(), input.substr(0, input.lastIndexOf('/'))

    fs.readdir inputPath, (err, files) =>
      files = files.filter (fileName) =>
        fragment = input.substr(input.lastIndexOf('/') + 1, input.length)
        isDir = fs.statSync(path.join(inputPath, fileName)).isDirectory()
        isDir and fileName.toLowerCase().indexOf(fragment) is 0

      callback.apply @, [files]

  autocomplete: (str) ->
    input = @miniEditor.getEditor().getText()
    inputPath = path.join atom.project.getPath(), input.substr(0, input.lastIndexOf('/'))

    @getDirs (files) ->
      if files.length == 1
        newPath = path.join(inputPath, files[0])
        relativePath = path.relative(atom.project.getPath(), newPath) + '/'
        @miniEditor.getEditor().setText relativePath
      else
        atom.beep()

  renderDirList: (files) ->
    @directoryList.empty()
    files.forEach (file) =>
      @directoryList.append $$ ->
        @li class: 'list-item', =>
        @span class: 'icon icon-file-directory', file

  confirm: ->
    filePath = @miniEditor.getEditor().getText()
    atom.open pathsToOpen: [path.join(atom.project.getPath(), filePath)]
    @detach()

  detach: ->
    @miniEditor.getEditor().setText ''
    @directoryList.empty()
    super

  toggle: ->
    if @hasParent()
      @detach()
    else
      atom.workspaceView.append(this)
      @miniEditor.focus()
