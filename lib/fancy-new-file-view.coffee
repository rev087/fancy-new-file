{$, $$, View, EditorView} = require 'atom'
fs = require 'fs'
path = require 'path'
mkdirp = require 'mkdirp'

module.exports =
class FancyNewFileView extends View
  fancyNewFileView: null
  @configDefaults:
    suggestCurrentFilePath: false

  @activate: (state) ->
    @fancyNewFileView = new FancyNewFileView(state.fancyNewFileViewState)

  @deactivate: ->
    @fancyNewFileView.detach()

  @content: (params)->
    @div class: 'fancy-new-file overlay from-top', =>
      @p outlet:'message', class:'icon icon-file-add', "Enter the path for the new file/directory. Directories end with a '" + path.sep + "'."
      @subview 'miniEditor', new EditorView({mini:true})
      @ul class: 'list-group', outlet: 'directoryList'

  @detaching: false,

  initialize: (serializeState) ->
    atom.workspaceView.command "fancy-new-file:toggle", => @toggle()
    @miniEditor.setPlaceholderText(path.join('path','to','file.txt'));

    @on 'core:confirm', => @confirm()
    @on 'core:cancel', => @detach()
    @miniEditor.hiddenInput.on 'focusout', => @detach() unless @detaching

    consumeKeypress = (ev) => ev.preventDefault(); ev.stopPropagation()

    # Populate the directory listing live
    @miniEditor.getEditor().getBuffer().on 'changed', (ev) => @update()

    # Consume the keydown event from holding down the Tab key
    @miniEditor.on 'keydown', (ev) => if ev.keyCode is 9 then consumeKeypress ev

    # Handle the Tab completion
    @miniEditor.on 'keyup', (ev) =>
      if ev.keyCode is 9
        consumeKeypress ev
        @autocomplete @miniEditor.getEditor().getText()

  # Retrieves the reference directory for the relative paths
  referenceDir: () ->
    homeDir = process.env.HOME or process.env.HOMEPATH or process.env.USERPROFILE
    atom.project.getPath() or homeDir

  # Resolves the path being inputted in the dialog, up to the last slash
  inputPath: () ->
    input = @miniEditor.getEditor().getText()
    path.join @referenceDir(), input.substr(0, input.lastIndexOf(path.sep))

  # Returns the list of directories matching the current input (path and autocomplete fragment)
  getDirs: (callback) ->
    input = @miniEditor.getEditor().getText()
    fs.readdir @inputPath(), (err, files) =>
      files = files?.filter (fileName) =>
        fragment = input.substr(input.lastIndexOf(path.sep) + 1, input.length)
        isDir = fs.statSync(path.join(@inputPath(), fileName)).isDirectory()
        isDir and fileName.toLowerCase().indexOf(fragment) is 0

      callback.apply @, [files]

  # Called only when pressing Tab to trigger auto-completion
  autocomplete: (str) ->
    @getDirs (files) ->
      if files?.length == 1
        newPath = path.join(@inputPath(), files[0])
        relativePath = atom.project.relativize(newPath) + path.sep
        @miniEditor.getEditor().setText relativePath
      else
        atom.beep()

  update: ->
    @getDirs (files) ->
      @renderDirList files

    if /\/$/.test @miniEditor.getEditor().getText()
      @setMessage 'file-directory-create'
    else
      @setMessage 'file-add'

  setMessage: (icon, str) ->
    @message.removeClass 'icon'\
      + ' icon-file-add'\
      + ' icon-file-directory-create'\
      + ' icon-alert'
    if icon? then @message.addClass 'icon icon-' + icon
    @message.text str or "Enter the path for the new file/directory. Directories end with a '" + path.sep + "'."

  # Renders the list of directories
  renderDirList: (dirs) ->
    @directoryList.empty()
    dirs?.forEach (file) =>
      @directoryList.append $$ ->
        @li class: 'list-item', =>
        @span class: 'icon icon-file-directory', file

  confirm: ->
    relativePath = @miniEditor.getEditor().getText()
    pathToCreate = path.join(@referenceDir(), relativePath)

    try
      if /\/$/.test(relativePath)
        mkdirp pathToCreate
      else
        atom.open pathsToOpen: [pathToCreate]
    catch error
      @setMessage 'alert', error.message

    @detach()

  detach: ->
    return unless @hasParent()
    @detaching = true
    @miniEditor.getEditor().setText ''
    @setMessage()
    @directoryList.empty()
    miniEditorFocused = @miniEditor.isFocused

    super

    @restoreFocus() if miniEditorFocused
    @detaching = false

  attach: ->
    @suggestPath()
    @previouslyFocusedElement = $(':focus')
    atom.workspaceView.append(this)
    @miniEditor.focus()
    @getDirs (files) -> @renderDirList files

  suggestPath: ->
    if atom.config.get 'fancy-new-file.suggestCurrentFilePath'
      activePath = atom.workspace.getActiveEditor()?.getPath()
      if activePath
        activeDir = path.dirname(activePath) + '/'
        suggestedPath = path.relative @referenceDir(), activeDir
        @miniEditor.getEditor().setText suggestedPath + '/'

  toggle: ->
    if @hasParent()
      @detach()
    else
      @attach()

  restoreFocus: ->
    if @previouslyFocusedElement?.isOnDom()
      @previouslyFocusedElement.focus()
    else
      atom.workspaceView.focus()
