class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  has_one :website, dependent: :destroy

  # Validation to ensure user can only have one website
  validates :website, uniqueness: true, allow_nil: true
end
