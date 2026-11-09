from django.apps import apps
from django.contrib.auth import logout
from django.shortcuts import get_object_or_404

from rest_framework import status
from rest_framework.authtoken.models import Token
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated, IsAdminUser
from rest_framework.response import Response

from .models import User
from .serializers import (
    UserSerializer,
    RegisterSerializer,
    LoginSerializer,
    ChangePasswordSerializer,
    ResetPasswordSerializer,
    ResetPasswordConfirmSerializer,
    UserCreateSerializer,
    UserUpdateSerializer,
)
from jwt_auth.password_reset import (
    GENERIC_REQUEST_MESSAGE,
    confirm_reset,
    send_reset_email,
)


# AUTH ENDPOINTS

@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.save()
        token, created = Token.objects.get_or_create(user=user)

        return Response(
            {
                "message": "User registered successfully.",
                "token": token.key,
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    serializer = LoginSerializer(data=request.data)

    if serializer.is_valid():
        user = serializer.validated_data["user"]
        token, created = Token.objects.get_or_create(user=user)

        return Response(
            {
                "message": "Login successful.",
                "token": token.key,
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_200_OK
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def logout_user(request):
    Token.objects.filter(user=request.user).delete()
    logout(request)

    return Response(
        {
            "message": "Logout successful."
        },
        status=status.HTTP_200_OK
    )


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    return Response(
        UserSerializer(request.user).data,
        status=status.HTTP_200_OK
    )


@api_view(["POST"])
@permission_classes([IsAuthenticated])
def change_password(request):
    serializer = ChangePasswordSerializer(data=request.data)

    if serializer.is_valid():
        user = request.user

        old_password = serializer.validated_data["old_password"]
        new_password = serializer.validated_data["new_password"]

        if not user.check_password(old_password):
            return Response(
                {
                    "old_password": "Old password is incorrect."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        user.set_password(new_password)
        user.save()

        Token.objects.filter(user=user).delete()

        return Response(
            {
                "message": "Password changed successfully. Please login again."
            },
            status=status.HTTP_200_OK
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([AllowAny])
def reset_password(request):
    """Step 1: emails a signed, expiring reset link. Always answers 200."""
    serializer = ResetPasswordSerializer(data=request.data)

    if serializer.is_valid():
        send_reset_email(serializer.validated_data["email"])
        return Response(
            {"message": GENERIC_REQUEST_MESSAGE},
            status=status.HTTP_200_OK
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["POST"])
@permission_classes([AllowAny])
def reset_password_confirm(request):
    """Step 2: sets the new password if uid + token are valid."""
    serializer = ResetPasswordConfirmSerializer(data=request.data)

    if serializer.is_valid():
        user, error = confirm_reset(
            serializer.validated_data["uid"],
            serializer.validated_data["token"],
            serializer.validated_data["new_password"],
        )

        if error:
            return Response(
                {"detail": error},
                status=status.HTTP_400_BAD_REQUEST
            )

        Token.objects.filter(user=user).delete()

        return Response(
            {
                "message": "Password reset successfully."
            },
            status=status.HTTP_200_OK
        )

    return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


# USER ENDPOINTS

@api_view(["GET", "POST"])
@permission_classes([IsAdminUser])
def users_list_create(request):
    if request.method == "GET":
        users = User.objects.all().order_by("-created_at")

        search = request.query_params.get("search")
        role = request.query_params.get("role")

        if search:
            users = users.filter(full_name__icontains=search) | users.filter(email__icontains=search)

        if role:
            users = users.filter(role=role)

        serializer = UserSerializer(users, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    if request.method == "POST":
        serializer = UserCreateSerializer(data=request.data)

        if serializer.is_valid():
            user = serializer.save()

            return Response(
                {
                    "message": "User created successfully.",
                    "user": UserSerializer(user).data,
                },
                status=status.HTTP_201_CREATED
            )

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


@api_view(["GET", "PATCH", "DELETE"])
@permission_classes([IsAdminUser])
def user_detail_update_delete(request, id):
    user = get_object_or_404(User, id=id)

    if request.method == "GET":
        serializer = UserSerializer(user)
        return Response(serializer.data, status=status.HTTP_200_OK)

    if request.method == "PATCH":
        serializer = UserUpdateSerializer(user, data=request.data, partial=True)

        if serializer.is_valid():
            user = serializer.save()

            return Response(
                {
                    "message": "User updated successfully.",
                    "user": UserSerializer(user).data,
                },
                status=status.HTTP_200_OK
            )

        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    if request.method == "DELETE":
        user.delete()

        return Response(
            {
                "message": "User deleted successfully."
            },
            status=status.HTTP_200_OK
        )


@api_view(["GET"])
@permission_classes([IsAdminUser])
def get_user_analyses(request, id):
    """
    Adapted from leafscan: analysis.plant/analysis.disease -> analysis.condition
    (the skin version has no separate "plant" concept, just one condition).
    """

    user = get_object_or_404(User, id=id)

    try:
        Analysis = apps.get_model("analyses", "Analysis")
    except LookupError:
        return Response(
            {
                "user": UserSerializer(user).data,
                "analyses": []
            },
            status=status.HTTP_200_OK
        )

    analyses = Analysis.objects.filter(user=user).order_by("-created_at")

    data = []

    for analysis in analyses:
        data.append(
            {
                "id": analysis.id,
                "analysis_key": analysis.analysis_key,
                "condition": analysis.condition.name if analysis.condition else None,
                "severity": analysis.condition.severity if analysis.condition else None,
                "confidence": analysis.confidence,
                "is_low_confidence": analysis.is_low_confidence,
                "created_at": analysis.created_at,
            }
        )

    return Response(
        {
            "user": UserSerializer(user).data,
            "analyses": data
        },
        status=status.HTTP_200_OK
    )
