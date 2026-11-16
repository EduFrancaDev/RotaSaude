from django.test import TestCase
from django.urls import reverse

from apps.services.models import Service


class ServiceListTests(TestCase):
    def test_lists_services_sorted_and_paginated(self):
        Service.objects.create(name="Pediatria", description="Atendimento infantil")
        Service.objects.create(name="Clínica geral")

        body = self.client.get(reverse("v1:service-list")).json()

        self.assertEqual(body["count"], 2)
        self.assertEqual([s["name"] for s in body["results"]], ["Clínica geral", "Pediatria"])
        self.assertEqual(set(body["results"][0]), {"id", "name", "description"})

    def test_empty_list(self):
        body = self.client.get(reverse("v1:service-list")).json()

        self.assertEqual(body, {"count": 0, "next": None, "previous": None, "results": []})
