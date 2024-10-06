use starknet::SyscallResult;
use dojo::utils::{Descriptor, DescriptorTrait};

use dojo::{
    utils::entity_id_from_keys,
    model::{
        Layout,
        introspect::{Introspect, Ty},
        layout::compute_packed_size,
        members::{set_serialized_member, get_serialized_member},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

#[derive(Copy, Drop, Serde, Debug, PartialEq)]
pub enum ModelIndex {
    Keys: Span<felt252>,
    Id: felt252,
    // (entity_id, member_id)
    MemberId: (felt252, felt252)
}

/// Trait that is implemented at Cairo level for each struct that is a model.
pub trait ModelEntity<T> {
    fn id(self: @T) -> felt252;
    fn values(self: @T) -> Span<felt252>;
    fn from_values(entity_id: felt252, values: Span<felt252>) -> T;
    // Get is always used with the trait path, which results in no ambiguity for the compiler.
    fn get(world: IWorldDispatcher, entity_id: felt252) -> T;
    // Update and delete can be used directly on the entity, which results in ambiguity.
    // Therefore, they are implemented with the `update_entity` and `delete_entity` names.
    fn update_entity(self: @T, world: IWorldDispatcher);
    fn delete_entity(self: @T, world: IWorldDispatcher);

    fn get_member(
        world: IWorldDispatcher, entity_id: felt252, member_id: felt252,
    ) -> Span<felt252>;

    fn set_member(world: IWorldDispatcher, entity_id: felt252, member_id: felt252, values: Span<felt252>);
}

pub trait Model<T> {
    // Get is always used with the trait path, which results in no ambiguity for the compiler.
    fn get(world: IWorldDispatcher, keys: Span<felt252>) -> T;
    // Note: `get` is implemented with a generated trait because it takes
    // the list of model keys as separated parameters.

    // Set and delete can be used directly on the entity, which results in ambiguity.
    // Therefore, they are implemented with the `set_model` and `delete_model` names.
    fn set_model(self: @T, world: IWorldDispatcher);
    fn delete_model(self: @T, world: IWorldDispatcher);

    fn get_member(
        world: IWorldDispatcher, keys: Span<felt252>, member_id: felt252,
    ) -> Span<felt252>;

    fn set_member(world: IWorldDispatcher, keys: Span<felt252>, member_id: felt252, values: Span<felt252>);

    /// Returns the name of the model as it was written in Cairo code.
    fn name() -> ByteArray;

    /// Returns the namespace of the model as it was written in the `dojo::model` attribute.
    fn namespace() -> ByteArray;

    // Returns the model tag which combines the namespace and the name.
    fn tag() -> ByteArray;

    fn version() -> u8;

    /// Returns the model selector built from its name and its namespace.
    /// model selector = hash(namespace_hash, model_hash)
    fn selector() -> felt252;
    fn instance_selector(self: @T) -> felt252;

    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;

    fn entity_id(self: @T) -> felt252;
    fn keys(self: @T) -> Span<felt252>;
    fn values(self: @T) -> Span<felt252>;
    fn layout() -> Layout;
    fn instance_layout(self: @T) -> Layout;
    fn packed_size() -> Option<usize>;
}

#[starknet::interface]
pub trait IModel<T> {
    fn name(self: @T) -> ByteArray;
    fn namespace(self: @T) -> ByteArray;
    fn tag(self: @T) -> ByteArray;
    fn version(self: @T) -> u8;

    fn selector(self: @T) -> felt252;
    fn name_hash(self: @T) -> felt252;
    fn namespace_hash(self: @T) -> felt252;
    fn unpacked_size(self: @T) -> Option<usize>;
    fn packed_size(self: @T) -> Option<usize>;
    fn layout(self: @T) -> Layout;
    fn schema(self: @T) -> Ty;
}

pub trait ModelAttributes<T> {
    const VERSION: u8;
    const SELECTOR: felt252;
    const NAME_HASH: felt252;
    const NAMESPACE_HASH: felt252;

    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    fn layout() -> Layout;
}

pub trait ModelKeyValueTrait<T> {
    fn entity_id(self: @T) -> felt252;
    fn serialized_keys(self: @T) -> Span<felt252>;
    fn serialized_values(self: @T) -> Span<felt252>;
    fn from_serialized_values(keys: Span<felt252>, values: Span<felt252>) -> T;
}

pub trait EntityIdValueTrait<T> {
    fn id(self: @T) -> felt252;
    fn serialized_values(self: @T) -> Span<felt252>;
    fn from_serialized_values(entity_id: felt252, values: Span<felt252>) -> T;
}

#[cfg(target: "test")]
pub trait ModelTest<T> {
    fn set_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}

#[cfg(target: "test")]
pub trait ModelEntityTest<T> {
    fn update_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}

pub impl ModelImpl<
    T, 
    +Serde<T>, 
    +Drop<T>, 
    +ModelAttributes<T>, 
    +Introspect<T>, 
    +ModelKeyValueTrait<T>
> of Model<T> {
    fn get(world: IWorldDispatcher, keys: Span<felt252>) -> T {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(keys),
            ModelAttributes::<T>::layout()
        );
        ModelKeyValueTrait::<T>::from_serialized_values(keys, values)
    }

   fn set_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(Self::keys(self)),
            ModelKeyValueTrait::<T>::serialized_values(self),
            ModelAttributes::<T>::layout()
        );
    }

    fn delete_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(ModelKeyValueTrait::<T>::serialized_keys(self)),
            ModelAttributes::<T>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252
    ) -> Span<felt252> {
        get_serialized_member(
            world, 
            entity_id_from_keys(keys), 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout()
        )
    }

    fn set_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252,
        values: Span<felt252>
    ) {
        set_serialized_member(
            world, entity_id_from_keys(keys), 
            ModelAttributes::<T>::SELECTOR,  
            member_id, 
            ModelAttributes::<T>::layout(), 
            values
        )
    }

    #[inline(always)]
    fn name() -> ByteArray {
        ModelAttributes::<T>::name()
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        ModelAttributes::<T>::namespace()
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        ModelAttributes::<T>::tag()
    }

    #[inline(always)]
    fn version() -> u8 {
        ModelAttributes::<T>::VERSION
    }

    #[inline(always)]
    fn selector() -> felt252 {
        ModelAttributes::<T>::SELECTOR
    }

    #[inline(always)]
    fn instance_selector(self: @T) -> felt252 {
        ModelAttributes::<T>::SELECTOR
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        ModelAttributes::<T>::NAME_HASH
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        ModelAttributes::<T>::NAMESPACE_HASH
    }

    #[inline(always)]
    fn entity_id(self: @T) -> felt252 {
        ModelKeyValueTrait::<T>::entity_id(self)
    }

    #[inline(always)]
    fn keys(self: @T) -> Span<felt252> {
        ModelKeyValueTrait::<T>::serialized_keys(self)
    }

    #[inline(always)]
    fn values(self: @T) -> Span<felt252> {
        ModelKeyValueTrait::<T>::serialized_values(self)
    }

    #[inline(always)]
    fn layout() -> Layout {
        ModelAttributes::<T>::layout()
    }

    #[inline(always)]
    fn instance_layout(self: @T) -> Layout {
        ModelAttributes::<T>::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        compute_packed_size(ModelAttributes::<T>::layout())
    }
}


pub impl ModelEntityImpl<
    T, 
    +Serde<T>, 
    +Drop<T>, 
    +ModelAttributes<T>, 
    +EntityIdValueTrait<T>
> of ModelEntity<T> {
    fn id(self: @T) -> felt252 {
        EntityIdValueTrait::<T>::id(self)
    }

    fn values(self: @T) -> Span<felt252> {
        EntityIdValueTrait::<T>::serialized_values(self)
    }

    fn from_values(entity_id: felt252, values: Span<felt252>) -> T {
        EntityIdValueTrait::<T>::from_serialized_values(entity_id, values)
    }

    fn get(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> T {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(entity_id),
            ModelAttributes::<T>::layout()
        );
        Self::from_values(entity_id, values)
    }

    fn update_entity(self: @T, world: dojo::world::IWorldDispatcher) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(Self::id(self)),
            Self::values(self),
            ModelAttributes::<T>::layout()
        );
    }

    fn delete_entity(self: @T, world: dojo::world::IWorldDispatcher) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(Self::id(self)),
            ModelAttributes::<T>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252
    ) -> Span<felt252> {
        get_serialized_member(
            world, 
            entity_id, 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout()
        )
    }

    fn set_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
        values: Span<felt252>
    ) {
        set_serialized_member(
            world, 
            entity_id, 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout(), 
            values
        )
    }
}
