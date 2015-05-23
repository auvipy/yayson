module.exports = (utils, adapter) ->
  class Presenter
    buildLinks = (link) ->
      return unless link?
      if link.self? || link.related?
        link
      else
        self: link

    @adapter: adapter
    type: 'objects'

    constructor: (scope = {}) ->
      @scope = scope

    id: (instance) ->
      adapter.id instance

    selfLinks: (instance) ->

    links: ->

    relationships: ->

    attributes: (instance) ->
      return null unless instance?
      attributes = utils.clone adapter.get instance
      if 'id' of attributes
        delete attributes['id']
      relationships = @relationships()
      for key of relationships
        delete attributes[key]
      attributes

    includeRelationships: (scope, instance) ->
      relationships = @relationships()
      for key of relationships
        factory = relationships[key] || throw new Error("Presenter for #{key} in #{@type} is not defined")
        presenter = new factory(scope)

        data = adapter.get instance, key
        presenter.toJSON data, include: true if data?

    buildRelationships: (instance) ->
      return null unless instance?
      rels = @relationships()
      links = @links(instance) || {}
      relationships = null
      for key of rels
        data = adapter.get instance, key
        presenter = rels[key]
        build = (d) ->
          rel =
            data:
              id: adapter.id d
              type: presenter::type
          if links[key]?
            rel.links = buildLinks links[key]
          rel
        relationships ||= {}
        relationships[key] ||= {}
        relationships[key]= if data instanceof Array
          data.map build
        else if data?
          build data
        else
          null
      relationships

    buildSelfLink: (instance) ->
      buildLinks @selfLinks(instance)

    toJSON: (instanceOrCollection, options = {}) ->
      @scope.meta = options.meta if options.meta?
      @scope.data ||= null

      return @scope unless instanceOrCollection?

      if instanceOrCollection instanceof Array
        collection = instanceOrCollection
        @scope.data ||= []
        collection.forEach (instance) =>
          @toJSON instance
      else
        instance = instanceOrCollection
        added = true
        model  =
          id: @id instance
          type: @type
          attributes: @attributes instance
        relationships = @buildRelationships instance
        model.relationships = relationships if relationships?
        links = @buildSelfLink instance
        model.links = links if links?

        if options.include
          @scope.included ||= []
          unless utils.any(@scope.included.concat(@scope.data), (i) -> i.id == model.id)
            @scope.included.push model
          else
            added = false
        else if @scope.data?
          unless utils.any(@scope.data, (i) -> i.id == model.id)
            @scope.data.push model
          else
            added = false
        else
          @scope.data = model

        @includeRelationships @scope, instance if added
      @scope

    render: (instanceOrCollection, options) ->
      if utils.isPromise(instanceOrCollection)
        instanceOrCollection.then (data) => @toJSON data, options
      else
        @toJSON instanceOrCollection, options

    @toJSON: ->
      (new this).toJSON arguments...

    @render: ->
      (new this).render arguments...


  module.exports = Presenter

