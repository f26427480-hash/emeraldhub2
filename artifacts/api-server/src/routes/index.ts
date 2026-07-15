import { Router, type IRouter } from "express";
import healthRouter from "./health";
import hubRouter from "./hub";

const router: IRouter = Router();

router.use(healthRouter);
router.use(hubRouter);

export default router;
