# frozen_string_literal: true

module Graphiform
  # Builds an ActiveRecord relation by applying Graphiform/Scopiform-style
  # customizations on top of a base relation.
  #
  # Used by both PreloaderSource (to compose the `scope:` handed to
  # ActiveRecord::Associations::Preloader) and Core#apply_built_ins (to apply
  # the same chain to top-level resolver relations).
  module ScopeComposer
    module_function

    # @param relation [ActiveRecord::Relation] starting relation (e.g. `Model.all`)
    # @param scope    [Proc, nil] optional scope block, `instance_exec`'d on the relation
    # @param where    [Hash, nil] Scopiform filter hash, applied via `apply_filters`
    # @param sort     [Hash, nil] Scopiform sort hash, applied via `apply_sorts`
    # @param includes [Symbol, Array, Hash, nil] eager-load spec passed to `includes`
    # @return [ActiveRecord::Relation]
    def compose(relation, scope: nil, where: nil, sort: nil, group: nil, includes: nil)
      relation = relation.merge(relation.instance_exec(&scope)) if scope.respond_to?(:call)
      relation = relation.includes(includes)                    if includes.present? && relation.respond_to?(:includes)
      relation = relation.apply_filters(where.to_h)             if where.present?    && relation.respond_to?(:apply_filters)
      relation = relation.apply_sorts(sort.to_h)                if sort.present?     && relation.respond_to?(:apply_sorts)
      relation = relation.apply_groupings(group.to_h)           if group.present?    && relation.respond_to?(:apply_groupings)
      relation
    end

    # True when any customization would actually modify the base relation.
    # Used by PreloaderSource to decide whether to hand a scope to upstream
    # (which disables result caching) or pass nil (which preserves it).
    def customized?(scope: nil, where: nil, sort: nil, group: nil, includes: nil)
      scope.respond_to?(:call) || where.present? || sort.present? || group.present? || includes.present?
    end
  end
end