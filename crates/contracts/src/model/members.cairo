use dojo::{
    utils::find_model_field_layout,
    model::{Layout, ModelIndex},
    world::{IWorldDispatcher, IWorldDispatcherTrait}
};
use core::{
    array::ArrayTrait,
    option::OptionTrait,
    panic_with_felt252,
    serde::Serde,
};



pub trait MemberTrait<T> {
    fn serialize(value: @T) -> Span<felt252>;
    fn deserialize(values: Span<felt252>) -> T;
}

pub trait MemberStore<T> {
    fn get_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
    ) -> T;
    fn update_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
        value: T,
    );
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
    use super::MemberImpl;

    pub trait KeyTrait<K> {
        fn serialize(key: @K) -> Span<felt252>;
        fn deserialize(keys: Span<felt252>) -> K;
        fn to_entity_id(key: @K) -> felt252;
    }

    pub impl KeyImpl<K, +MemberTrait<K>> of KeyTrait<K> {
        fn serialize(key: @K) -> Span<felt252> {
            MemberTrait::<K>::serialize(key)
        }
    
        fn deserialize(keys: Span<felt252>) -> K {
            MemberTrait::<K>::deserialize(keys)
        }
    
        fn to_entity_id(key: @K) -> felt252 {
            poseidon_hash_span(MemberTrait::<K>::serialize(key))
        }
    }
}




pub impl MemberStoreImpl<T, M, +ModelAttributes<M>, +MemberStore<T>> of MemberStore<T> {
    fn get_member(
        self: @IWorldDispatcher,
        entity_id: felt252,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
    ) -> T {
        Member::deserialize(get_serialized_member(
            self, ModelAttributes::M>::SELECTOR, member_id, ModelAttributes::M>::layout(), entity_id
        ))
    }
    fn update_member(
        self: IWorldDispatcher,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
        entity_id: felt252,
        value: T,
    ) {
        
        set_serialized_member(self, entity_id, model_id, member_id, layout, Member::serialize(value))
    }
}




