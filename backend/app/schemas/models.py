from datetime import date
from decimal import Decimal
from typing import Annotated
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field, StrictInt, field_validator, model_validator

PositiveInt = Annotated[StrictInt, Field(gt=0)]


class Input(BaseModel):
    model_config = ConfigDict(extra='forbid', str_strip_whitespace=True)


class Login(Input):
    username: str = Field(min_length=1, max_length=80)
    password: str = Field(min_length=1, max_length=200)


class CategoryInput(Input):
    name: str = Field(min_length=1, max_length=100)
    description: str = Field(default='', max_length=500)


class ProductInput(Input):
    code: str = Field(min_length=1, max_length=40)
    name: str = Field(min_length=1, max_length=150)
    description: str = Field(default='', max_length=500)
    category_id: PositiveInt
    unit_id: PositiveInt
    price: Decimal = Field(gt=0, max_digits=18, decimal_places=2)
    min_stock: Annotated[StrictInt, Field(ge=0)]
    tracks_expiry: bool = True

    @field_validator('code')
    @classmethod
    def normalize_code(cls, value):
        return value.upper()


class MovementInput(Input):
    request_id: UUID
    product_id: PositiveInt
    quantity: PositiveInt
    movement_date: date
    reason: str = Field(min_length=1, max_length=250)
    entry_reason_id: PositiveInt | None = None
    area_id: PositiveInt | None = None
    lot_code: str | None = Field(default=None, min_length=1, max_length=80)
    expiry: date | None = None

    @model_validator(mode='after')
    def validate_date(self):
        from datetime import datetime
        # Peru has fixed UTC-5; avoids depending on Windows zoneinfo data.
        from datetime import timezone, timedelta
        if self.movement_date > datetime.now(timezone(timedelta(hours=-5))).date():
            raise ValueError('La fecha no puede ser futura')
        return self
