use core::num::traits::Zero;
use core::ops::AddAssign;
use core::option::Option;
use core::poseidon::poseidon_hash_span;
use core::serde::Serde;

use dojo::meta::{Layout, FieldLayout};

#[inline(always)]
fn is_letter(c: u8) -> bool {
    (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}


#[inline(always)]
fn is_numeric(c: u8) -> bool {
    c >= '0' && c <= '9'
}

/// Verifies that the provided name is valid according to the following RegEx: ^[a-zA-Z0-9_]+$
pub fn is_name_valid(name: @ByteArray) -> bool {
    let mut i = 0;
    loop {
        if i >= name.len() {
            break true;
        }

        let c = name.at(i).unwrap();

        if !is_letter(c) && !is_numeric(c) && c != '_' {
            break false;
        }

        i += 1;
    }
}

/// Compute the poseidon hash of a serialized ByteArray
pub fn bytearray_hash(data: @ByteArray) -> felt252 {
    let mut serialized = ArrayTrait::new();
    Serde::serialize(data, ref serialized);
    poseidon_hash_span(serialized.span())
}

/// Computes the selector of a resource from the namespace and the name.
pub fn selector_from_names(namespace: @ByteArray, name: @ByteArray) -> felt252 {
    poseidon_hash_span([bytearray_hash(namespace), bytearray_hash(name)].span())
}

/// Computes the entity id from the keys.
///
/// # Arguments
///
/// * `keys` - The keys of the entity.
///
/// # Returns
///
/// The entity id.
pub fn entity_id_from_keys(keys: Span<felt252>) -> felt252 {
    poseidon_hash_span(keys)
}

/// find a field with its selector in a list of layouts
pub fn find_field_layout(
    field_selector: felt252, field_layouts: Span<FieldLayout>
) -> Option<Layout> {
    let mut i = 0;
    let layout = loop {
        if i >= field_layouts.len() {
            break Option::None;
        }

        let field_layout = *field_layouts.at(i);
        if field_selector == field_layout.selector {
            break Option::Some(field_layout.layout);
        }

        i += 1;
    };

    layout
}

/// Find the layout of a model field based on its selector.
///
/// # Arguments
///
/// * `model_layout` - The full model layout (must be a Layout::Struct).
/// *  `member_selector` - The model field selector.
///
/// # Returns
/// Some(Layout) if the field layout has been found, None otherwise.
pub fn find_model_field_layout(model_layout: Layout, member_selector: felt252) -> Option<Layout> {
    match model_layout {
        Layout::Struct(field_layouts) => { find_field_layout(member_selector, field_layouts) },
        _ => {
            // should never happen as model layouts are always struct layouts.
            core::panic_with_felt252('Unexpected model layout');
            Option::None
        }
    }
}

/// Indicates if at least one array item is None.
pub fn any_none<T>(arr: @Array<Option<T>>) -> bool {
    let mut i = 0;
    let mut res = false;
    loop {
        if i >= arr.len() {
            break;
        }

        if arr.at(i).is_none() {
            res = true;
            break;
        }
        i += 1;
    };
    res
}

/// Compute the sum of array items.
/// Note that there is no overflow check as we expect small array items.
pub fn sum<T, +Drop<T>, +Copy<T>, +AddAssign<T, T>, +Zero<T>>(arr: Array<Option<T>>) -> T {
    let mut i = 0;
    let mut res = Zero::<T>::zero();

    loop {
        if i >= arr.len() {
            break res;
        }
        res += (*arr.at(i)).unwrap();
        i += 1;
    }
}

/// Combine parent and child keys to build one full key.
pub fn combine_key(parent_key: felt252, child_key: felt252) -> felt252 {
    poseidon_hash_span([parent_key, child_key].span())
}
