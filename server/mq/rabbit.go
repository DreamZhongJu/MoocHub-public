package mq

import (
	"MOOCHUB-server/config"
	"MOOCHUB-server/utils"
	"context"
	"strings"
	"time"

	amqp "github.com/rabbitmq/amqp091-go"
)

var conn *amqp.Connection
var ch *amqp.Channel

const (
	exchangeName = "moochub.events"
	traceHeader  = "x-trace-id"
)

func InitRabbitMQ() error {
	var err error
	conn, err = amqp.Dial(config.RabbitMQURL())
	if err != nil {
		return err
	}
	ch, err = conn.Channel()
	if err != nil {
		return err
	}
	return ch.ExchangeDeclare(
		exchangeName,
		"topic",
		true,
		false,
		false,
		false,
		nil,
	)
}

func Publish(routingKey string, body []byte) error {
	return PublishWithTrace(routingKey, body, "")
}

func PublishWithTrace(routingKey string, body []byte, traceID string) error {
	if ch == nil {
		return nil
	}
	headers := amqp.Table{}
	if tid := strings.TrimSpace(traceID); tid != "" {
		headers[traceHeader] = tid
	}
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
	defer cancel()
	return utils.Retry(ctx, 3, 80*time.Millisecond, 500*time.Millisecond, func(err error) bool {
		return true
	}, func() error {
		return ch.PublishWithContext(
			ctx,
			exchangeName,
			routingKey,
			false,
			false,
			amqp.Publishing{
				ContentType: "application/json",
				Body:        body,
				Headers:     headers,
			},
		)
	})
}

func Consume(routingKey, queueName string) (<-chan amqp.Delivery, error) {
	if ch == nil {
		return nil, nil
	}
	q, err := ch.QueueDeclare(
		queueName,
		true,
		false,
		false,
		false,
		nil,
	)
	if err != nil {
		return nil, err
	}
	if err := ch.QueueBind(q.Name, routingKey, exchangeName, false, nil); err != nil {
		return nil, err
	}
	return ch.Consume(
		q.Name,
		"",
		false,
		false,
		false,
		false,
		nil,
	)
}

func CloseRabbitMQ() {
	if ch != nil {
		_ = ch.Close()
	}
	if conn != nil {
		_ = conn.Close()
	}
}

func TraceIDFromDelivery(msg amqp.Delivery) string {
	if msg.Headers == nil {
		return ""
	}
	raw, ok := msg.Headers[traceHeader]
	if !ok {
		return ""
	}
	if s, ok := raw.(string); ok {
		return strings.TrimSpace(s)
	}
	return ""
}
