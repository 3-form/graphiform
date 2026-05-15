# frozen_string_literal: true

require 'graphql'
require 'graphql/dataloader'
require 'graphql/dataloader/source'
require 'graphql/dataloader/active_record_association_source'
require 'graphiform/scope_composer'

module Graphiform
  # Loads ActiveRecord associations through the dataloader, with optional
  # Scopiform-style `where`/`sort`/`includes`/`scope` composition applied to
  # the relation handed to ActiveRecord::Associations::Preloader.
  #
  # Inherits batching semantics (including `scope.to_sql`-based batch keys),
  # `assoc.loaded?` short-circuiting, polymorphic handling, and cross-source
  # cache reuse from GraphQL::Dataloader::ActiveRecordAssociationSource.
  #
  # Usage:
  #
  #   dataloader.with(
  #     Graphiform::PreloaderSource,
  #     :posts,
  #     klass: User.reflect_on_association(:posts).klass,
  #     scope: association_reflection.scope,
  #     where: args[:where],
  #     sort:  args[:sort],
  #   ).load(user_record)
  class PreloaderSource < ::GraphQL::Dataloader::ActiveRecordAssociationSource
    # @param association_name [Symbol] the association on the parent record(s)
    # @param klass            [Class, nil] target model class used to build the
    #   composed scope. Required when any of `scope`/`where`/`sort`/`includes`
    #   is given; may be nil for bare preloads.
    # @param scope    [Proc, nil]
    # @param where    [Hash, nil]
    # @param sort     [Hash, nil]
    # @param includes [Symbol, Array, Hash, nil]
    def initialize(association_name, klass: nil, scope: nil, where: nil, sort: nil, includes: nil)
      effective_scope = build_scope(klass, scope: scope, where: where, sort: sort, includes: includes)
      super(association_name, effective_scope)
    end

    # Mirror initialize's scope composition so the batch key (which upstream
    # derives from the scope via `scope.to_sql`) is consistent across loads
    # that should batch together.
    def self.batch_key_for(association_name, klass: nil, scope: nil, where: nil, sort: nil, includes: nil)
      effective_scope = build_scope(klass, scope: scope, where: where, sort: sort, includes: includes)
      super(association_name, effective_scope)
    end

    def self.build_scope(klass, scope: nil, where: nil, sort: nil, includes: nil)
      return nil unless klass
      return nil unless ScopeComposer.customized?(scope: scope, where: where, sort: sort, includes: includes)

      ScopeComposer.compose(klass.all, scope: scope, where: where, sort: sort, includes: includes)
    end

    # Instance-level helper kept for symmetry / overrideability.
    def build_scope(klass, **kwargs)
      self.class.build_scope(klass, **kwargs)
    end
  end
end