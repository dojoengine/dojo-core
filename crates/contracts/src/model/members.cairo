use dojo::{
    utils::find_model_field_layout,
    meta::Layout,
    model::{attributes::ModelIndex, ModelAttributes},
    world::{IWorldDispatcher, IWorldDispatcherTrait}
};
use core::panic_with_felt252;



pub trait MemberTrait<T> {
    fn serialize(value: T) -> Span<felt252>;
    fn deserialize(values: Span<felt252>) -> T;
}

pub trait MemberStore<M, T> {
    fn get_member(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252,) -> T;
    fn update_member(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T);
}


fn update_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    entity_id: felt252,
    values: Span<felt252>,
) {
    match find_model_field_layout(layout, member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::set_entity(
                world,
                model_id,
                ModelIndex::MemberId((entity_id, member_id)),
                values,
                field_layout,

            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}

fn get_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    entity_id: felt252,
) -> Span<felt252> {
    match find_model_field_layout(layout, 
         member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::entity(
                world,
                model_id,
                ModelIndex::MemberId((entity_id, member_id)),
                field_layout
            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}


pub impl MemberImpl<T, +Serde<T>, +Drop<T>> of MemberTrait<T> {
    
    fn serialize(value: T) -> Span<felt252> {
        let mut serialized = ArrayTrait::new();
        Serde::<T>::serialize(@value, ref serialized);
        serialized.span()
    }

    fn deserialize(values: Span<felt252>) -> T {
        let mut values = values.into();
        let value = Serde::<T>::deserialize(ref values);
        match value {
            Option::Some(value) => value,
            Option::None => panic!("Member: deserialization failed.")
        }
    }
}

pub mod key {
    use super::MemberTrait;
    use dojo::utils::entity_id_from_keys;

    pub trait KeyParserTrait<M, K>{
        fn key(self: @M) -> K;
    }

    pub trait KeyTrait<K> {
        fn serialize(self: @K) -> Span<felt252>;
        fn deserialize(keys: Span<felt252>) -> K;
        fn to_entity_id(self: @K) -> felt252;
    }

    pub impl KeyImpl<K, +MemberTrait<K>, +Copy<K>> of KeyTrait<K> {
        fn serialize(self: @K) -> Span<felt252> {
            MemberTrait::<K>::serialize(*self)
        }
    
        fn deserialize(keys: Span<felt252>) -> K {
            MemberTrait::<K>::deserialize(keys)
        }
    
        fn to_entity_id(self: @K) -> felt252 {
            entity_id_from_keys(Self::serialize(self))
        }
    }
}




pub impl MemberStoreImpl<M, T, +ModelAttributes<M>, +MemberTrait<T>, +Drop<T>, +Drop<M>> of MemberStore<M, T> {
    fn get_member(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252,) -> T {
        MemberTrait::<T>::deserialize(get_serialized_member(
            *self, ModelAttributes::<M>::selector(), member_id, ModelAttributes::<M>::layout(), entity_id
        ))
    }
    fn update_member(
        self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T,
    ) {
        
        update_serialized_member(
            self, ModelAttributes::<M>::selector(), member_id, ModelAttributes::<M>::layout(), entity_id, MemberTrait::<T>::serialize(value)
        )
    }
}




