use dojo::model::{Model, Entity, ModelStore, EntityStore};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

use dojo::tests::helpers::{deploy_world};
use dojo::utils::test::{spawn_test_world};

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
struct Foo {
    #[key]
    k1: u8,
    #[key]
    k2: felt252,
    v1: u128,
    v2: u32
}

#[test]
fn test_id() {
    let mvalues = FooEntity { __id: 1, v1: 3, v2: 4 };
    assert!(mvalues.id() == 1);
}

#[test]
fn test_values() {
    let mvalues = FooEntity { __id: 1, v1: 3, v2: 4 };
    let expected_values = [3, 4].span();

    let values = mvalues.values();
    assert!(expected_values == values);
}

#[test]
fn test_from_values() {
    let mut values = [3, 4].span();

    let model_entity: Option<FooEntity> = Entity::from_values(1, ref values);
    assert!(model_entity.is_some());
    let model_entity = model_entity.unwrap();
    assert!(model_entity.__id == 1 && model_entity.v1 == 3 && model_entity.v2 == 4);
}

#[test]
fn test_from_values_bad_data() {
    let mut values = [3].span();
    let res: Option<FooEntity> = Entity::from_values(1, ref values);
    assert!(res.is_none());
}

#[test]
fn test_get_and_update_entity() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let entity_id = foo.entity_id();
    let mut entity: FooEntity = world.get_entity(entity_id);
    assert!(entity.__id == entity_id && entity.v1 == entity.v1 && entity.v2 == entity.v2);

    entity.v1 = 12;
    entity.v2 = 18;

    world.update(entity);

    let read_values: FooEntity = world.get_entity(entity_id);
    assert!(read_values.v1 == entity.v1 && read_values.v2 == entity.v2);
}

#[test]
fn test_delete_entity() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let entity_id = foo.entity_id();
    let mut entity: FooEntity = world.get_entity(entity_id);
    EntityStore::<FooEntity>::delete_from_id(world, entity.id());

    let read_values: FooEntity = world.get_entity(entity_id);
    assert!(read_values.v1 == 0 && read_values.v2 == 0);
}

#[test]
fn test_get_and_set_member_from_entity() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let v1: u128 = EntityStore::<
        FooEntity
    >::get_member_from_id(@world, foo.entity_id(), selector!("v1"));

    assert!(v1 == 3);

    let entity: FooEntity = world.get_entity(foo.entity_id());
    EntityStore::<FooEntity>::update_member_from_id(world, entity.id(), selector!("v1"), 42);

    let entity: FooEntity = world.get_entity(foo.entity_id());
    assert!(entity.v1 == 42);
}

#[test]
fn test_get_and_set_field_name() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let v1 = FooEntityStore::get_v1(world, foo.entity_id());
    assert!(foo.v1 == v1);

    let _entity: FooEntity = world.get_entity(foo.entity_id());

    FooEntityStore::set_v1(world, foo.entity_id(), 42);

    let v1 = FooEntityStore::get_v1(world, foo.entity_id());
    assert!(v1 == 42);
}

#[test]
fn test_get_and_set_from_model() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let read_entity: Foo = world.get((foo.k1, foo.k2));

    assert!(
        foo.k1 == read_entity.k1
            && foo.k2 == read_entity.k2
            && foo.v1 == read_entity.v1
            && foo.v2 == read_entity.v2
    );
}

#[test]
fn test_delete_from_model() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);
    ModelStore::<Foo>::delete(world, (foo.k1, foo.k2));

    let read_entity: Foo = world.get((foo.k1, foo.k2));
    assert!(
        read_entity.k1 == foo.k1
            && read_entity.k2 == foo.k2
            && read_entity.v1 == 0
            && read_entity.v2 == 0
    );
}

#[test]
fn test_get_and_set_member_from_model() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    let keys = [foo.k1.into(), foo.k2.into()].span();
    world.set(foo);

    let v1_raw_value = Model::<Foo>::get_member(world, keys, selector!("v1"));

    assert!(v1_raw_value.len() == 1);
    assert!(*v1_raw_value.at(0) == 3);

    FooModelImpl::set_member(world, keys, selector!("v1"), [42].span());
    let foo = FooStore::get(world, foo.k1, foo.k2);
    assert!(foo.v1 == 42);
}

#[test]
fn test_get_and_set_field_name_from_model() {
    let world = deploy_world();
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let foo = Foo { k1: 1, k2: 2, v1: 3, v2: 4 };
    world.set(foo);

    let v1 = FooStore::get_v1(world, foo.k1, foo.k2);
    assert!(v1 == 3);

    FooStore::set_v1(world, foo.k1, foo.k2, 42);

    let v1 = FooStore::get_v1(world, foo.k1, foo.k2);
    assert!(v1 == 42);
}

