"""generate_chat_answer: retries, lighter-model fallback, safe fallback message.
Gemini is ALWAYS mocked - the real API is never called."""

import os
from types import SimpleNamespace
from unittest import mock

from django.test import SimpleTestCase
from google.genai.errors import APIError

from analyses.services import gemini_service


class ScriptedClient:
    """Each call pops the next outcome: an exception to raise or text to return."""

    def __init__(self, outcomes):
        self.outcomes = list(outcomes)
        self.models_used = []
        self.models = SimpleNamespace(generate_content=self._generate)

    def _generate(self, model, contents, config):
        self.models_used.append(model)
        outcome = self.outcomes.pop(0)
        if isinstance(outcome, Exception):
            raise outcome
        return SimpleNamespace(text=outcome)


def timeout_error():
    return APIError(504, {"error": {"message": "DEADLINE_EXCEEDED"}})


@mock.patch.dict(os.environ, {"GEMINI_API_KEY": "test-key"})
@mock.patch("analyses.services.gemini_service.time.sleep")
class ChatAnswerTests(SimpleTestCase):
    def ask(self, client):
        with mock.patch.object(gemini_service, "_make_client", return_value=client):
            return gemini_service.generate_chat_answer("Acne", "LOW", "desc", [], "Is it serious?")

    def test_success_after_one_retry(self, sleep):
        client = ScriptedClient([timeout_error(), "A calm answer."])
        self.assertEqual(self.ask(client), "A calm answer.")
        self.assertEqual(len(client.models_used), 2)
        sleep.assert_called_once()

    def test_retries_503_and_429(self, sleep):
        client = ScriptedClient([APIError(503, {"error": {"message": "x"}}), APIError(429, {"error": {"message": "x"}}), "ok"])
        self.assertEqual(self.ask(client), "ok")

    def test_last_retry_uses_lighter_model(self, sleep):
        client = ScriptedClient([timeout_error(), timeout_error(), "From lite."])
        self.assertEqual(self.ask(client), "From lite.")
        self.assertEqual(
            client.models_used,
            [gemini_service.GEMINI_MODEL, gemini_service.GEMINI_MODEL, gemini_service.GEMINI_FALLBACK_MODEL],
        )

    def test_all_attempts_fail_returns_safe_fallback_and_logs(self, sleep):
        client = ScriptedClient([timeout_error(), timeout_error(), timeout_error()])
        with self.assertLogs("analyses.services.gemini_service", level="ERROR") as logs:
            answer = self.ask(client)
        self.assertEqual(answer, gemini_service.CHAT_ANSWER_FALLBACK)
        self.assertEqual(len(client.models_used), 3)
        self.assertIn("504", "".join(logs.output))

    def test_non_retryable_error_is_not_retried(self, sleep):
        client = ScriptedClient([APIError(400, {"error": {"message": "bad"}})])
        self.assertEqual(self.ask(client), gemini_service.CHAT_ANSWER_FALLBACK)
        self.assertEqual(len(client.models_used), 1)


@mock.patch("analyses.services.gemini_service.time.sleep")
class RecommendationBudgetTests(SimpleTestCase):
    def test_504_is_not_retried_outside_chat(self, sleep):
        client = ScriptedClient([timeout_error()])
        with self.assertRaises(APIError):
            gemini_service._generate_content_with_retry(client, "p", None)
        self.assertEqual(len(client.models_used), 1)

    def test_retry_skipped_when_it_could_exceed_budget(self, sleep):
        client = ScriptedClient([APIError(503, {"error": {"message": "x"}}), "late"])
        with self.assertRaises(APIError):
            gemini_service._generate_content_with_retry(
                client, "p", None, attempt_timeout_s=40, budget_s=30
            )
        self.assertEqual(len(client.models_used), 1)

    def test_worst_case_recommendation_time_fits_mobile_scan_timeout(self, sleep):
        # first attempt 40s + (backoff + 40s) retry must stay under 60s
        self.assertLessEqual(gemini_service._RECOMMENDATION_BUDGET_S, 55)
