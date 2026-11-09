from django.contrib.auth import get_user_model
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer

User = get_user_model()


class JwtUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "full_name",
            "email",
            "role",
            "created_at",
        ]
        read_only_fields = ["id", "created_at"]


class JwtRegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=6)
    username = serializers.CharField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "full_name",
            "email",
            "password",
        ]
        read_only_fields = ["id"]

    def create(self, validated_data):
        email = validated_data["email"]
        username = validated_data.get("username") or email

        user = User.objects.create_user(
            username=username,
            email=email,
            password=validated_data["password"],
            full_name=validated_data["full_name"],
        )

        return user


class JwtLoginSerializer(TokenObtainPairSerializer):
    def validate(self, attrs):
        data = super().validate(attrs)

        data["user"] = JwtUserSerializer(self.user).data

        return data


class JwtChangePasswordSerializer(serializers.Serializer):
    old_password = serializers.CharField(write_only=True)
    new_password = serializers.CharField(write_only=True, min_length=6)


class JwtResetPasswordRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class JwtResetPasswordConfirmSerializer(serializers.Serializer):
    uid = serializers.CharField()
    token = serializers.CharField()
    new_password = serializers.CharField(write_only=True, min_length=6)
