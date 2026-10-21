"""OpenTelemetry setup — NOT YET WIRED.

Enable when at least 2 services exist and you need distributed tracing.

Steps to enable:
    1. pip install opentelemetry-distro opentelemetry-exporter-otlp
    2. opentelemetry-bootstrap --action=install
    3. Uncomment the setup function below.
    4. Set env vars:
       OTEL_SERVICE_NAME=oryonfoods-auth
       OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector:4318
       OTEL_TRACES_SAMPLER=parentbased_traceidratio
       OTEL_TRACES_SAMPLER_ARG=0.1

##############################################################################
# import logging
# from opentelemetry import trace
# from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
# from opentelemetry.sdk.trace import TracerProvider
# from opentelemetry.sdk.trace.export import BatchSpanProcessor
#
# logger = logging.getLogger(__name__)
#
# def configure_telemetry(service_name: str = "oryonfoods-auth") -> None:
#     provider = TracerProvider()
#     exporter = OTLPSpanExporter()
#     processor = BatchSpanProcessor(exporter)
#     provider.add_span_processor(processor)
#     trace.set_tracer_provider(provider)
#     logger.info("OpenTelemetry configured", service=service_name)
##############################################################################
"""


def configure_telemetry() -> None:
    """Placeholder — does nothing until OpenTelemetry deps are added."""
    pass
