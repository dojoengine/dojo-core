    fn get_$field_name$(world: dojo::world::IWorldDispatcher, $param_keys$) -> $field_type$ {
        dojo::model::members::MemberSerdeImpl::<$field_type$>::deserialize_member(
            $model_name$ModelImpl::get_member(
                world,
                Self::serialize_keys($keys$),
                $field_selector$
            )
        )
    }

    
    fn set_$field_name$(world: dojo::world::IWorldDispatcher, $param_keys$, value: $field_type$) {
        $model_name$ModelImpl::set_member(
            world,
            Self::serialize_keys($keys$),
            $field_selector$,
            dojo::model::members::MemberSerdeImpl::<$field_type$>::serialize_member(value)
        );
    }

