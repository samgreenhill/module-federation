import {
  APIGatewayProxyEvent,
  APIGatewayProxyResult
} from "aws-lambda";
export const handler = async (
  event: APIGatewayProxyEvent
): Promise<APIGatewayProxyResult> => {
  console.log(`Event: ${JSON.stringify(event)}`);
  return {
    statusCode: 200,
    body: "Hello World"
  }
}